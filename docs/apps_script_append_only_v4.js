const SECRET = 'maliyati-2026';
const SCRIPT_VERSION = '1.4.5';
const SHEET_NAME = '';
const FIRST_DATA_ROW = 2;
const SOURCE_VALUES = ['application', 'Google Sheet', 'script'];
const STATUS_VALUES = ['Income', 'Expense', 'Credit', 'Debt', 'Transfer'];
const SETTLEMENT_VALUES = ['open', 'partial', 'settled'];
const PAYMENT_TIMING_VALUES = ['Paid Now', 'On Credit'];

function setupSheetMetadata() {
  const sheet = getSheet_();
  const columns = ensureSheetColumns_(sheet);
  applyCreatedAtFormat_(sheet, columns.createdAt);
  applySourceDropdown_(sheet, columns.source);
  applyStatusDropdown_(sheet, columns.status);
  applySettlementDropdown_(sheet, columns.settlementStatus);
  applyPaymentTimingDropdown_(sheet, columns.paymentTiming);
  applySourceColors_(sheet, columns.source);
  applyStatusColors_(sheet, columns.status);
}

function doGet(e) {
  try {
    const params = e && e.parameter ? e.parameter : {};
    if (params.secret === SECRET && params.action === 'list_transactions') {
      const sheet = getSheet_();
      return json_({ ok: true, rows: listTransactions_(sheet) });
    }
      return ContentService
      .createTextOutput(`Maliyati Apps Script ${SCRIPT_VERSION} is running. Use POST from the app.`)
      .setMimeType(ContentService.MimeType.TEXT);
  } catch (error) {
    return json_({
      ok: false,
      error: String(error && error.message ? error.message : error)
    });
  }
}

function doPost(e) {
  try {
    const payload = parsePayload_(e);
    if (payload.secret !== SECRET) {
      return json_({ ok: false, error: 'Unauthorized' });
    }

    const sheet = getSheet_();
    const action = String(payload.action || '').trim();
    if (action === 'list_transactions') {
      return json_({ ok: true, rows: listTransactions_(sheet) });
    }
    if (
      action === 'add_transaction' ||
      action === 'insert_transaction' ||
      action === 'insert' ||
      action === 'upsert_transaction' ||
      action === 'update_transaction' ||
      action === 'edit_transaction' ||
      action === 'update_now'
    ) {
      const result = upsertTransaction_(sheet, payload.row || payload);
      return json_({ ok: true, row: result.row, id: result.id });
    }
    if (action === 'delete_transaction' || action === 'delete' || action === 'remove_transaction') {
      const result = deleteTransaction_(sheet, payload.row || payload);
      return json_({ ok: true, ...result });
    }
    if (action === 'settle_transaction' || action === 'settle' || action === 'collect_credit' || action === 'pay_debt') {
      const result = settleTransaction_(sheet, payload.row || payload);
      return json_({ ok: true, ...result });
    }
    if (action === 'sync_transactions') {
      const result = syncTransactions_(sheet, payload.rows || []);
      return json_({ ok: true, ...result });
    }

    return json_({ ok: false, error: `Unsupported action: ${action}` });
  } catch (error) {
    return json_({
      ok: false,
      error: String(error && error.message ? error.message : error)
    });
  }
}

function testAppendSample() {
  const fakeRequest = {
    postData: {
      contents: JSON.stringify({
        secret: SECRET,
        action: 'upsert_transaction',
        row: {
          Date: '2026-07-14',
          Status: 'Expense',
          Title: 'Test from Apps Script',
          'Amount ($)': 1.25,
          'Amount (LBP)': 0,
          Category: 'Home expenses',
          'Payment Method': 'Cash',
          'Payment Timing': 'Paid Now',
          Notes: 'Delete this row after test',
          'Created At': new Date(),
          Source: 'script',
          Wallet: 'Cash',
          'Destination Wallet': '',
          'Wallet Direction': -1,
          'Settlement Status': 'open',
          'Linked Transaction ID': '',
          ID: `test-${Date.now()}`
        }
      })
    }
  };

  Logger.log(doPost(fakeRequest).getContent());
}

function upsertTransaction_(sheet, input) {
  const columns = ensureSheetColumns_(sheet);
  const id = value_(input, ['ID', 'id', 'Transaction ID', 'transaction_id']) || nextTransactionId_(sheet, columns.id);
  const rowValues = buildRowObject_(input);
  const source = normalizeSource_(value_(input, ['Source', 'source']) || 'application');
  const existingRow = findRowById_(sheet, columns.id, id);
  const targetRow = existingRow || Math.max(sheet.getLastRow() + 1, FIRST_DATA_ROW);
  const previousCreatedAt = existingRow
    ? sheet.getRange(existingRow, columns.createdAt).getValue()
    : '';
  const createdAt = normalizeCreatedAt_(
    value_(input, ['Created At', 'created_at', 'createdAt']) || previousCreatedAt || new Date()
  );

  writeTransactionRow_(sheet, targetRow, columns, rowValues);
  sheet.getRange(targetRow, columns.createdAt).setValue(dateTimeText_(createdAt));
  sheet.getRange(targetRow, columns.source).setValue(source);
  sheet.getRange(targetRow, columns.id).setValue(id);
  return { row: targetRow, id };
}

function syncTransactions_(sheet, rows) {
  if (!Array.isArray(rows)) {
    throw new Error('sync_transactions needs rows array.');
  }
  const columns = ensureSheetColumns_(sheet);
  const incomingIds = new Set();
  let added = 0;
  let updated = 0;

  rows.forEach((input) => {
    const id = String(value_(input, ['ID', 'id', 'Transaction ID', 'transaction_id']) || nextTransactionId_(sheet, columns.id)).trim();
    if (!id) {
      return;
    }
    incomingIds.add(id);
    const existingRow = findRowById_(sheet, columns.id, id);
    const targetRow = existingRow || Math.max(sheet.getLastRow() + 1, FIRST_DATA_ROW);
    const previousCreatedAt = existingRow
      ? sheet.getRange(existingRow, columns.createdAt).getValue()
      : '';
    const createdAt = normalizeCreatedAt_(
      value_(input, ['Created At', 'created_at', 'createdAt']) || previousCreatedAt || new Date()
    );
    const rowValues = buildRowObject_(input);
    const source = normalizeSource_(value_(input, ['Source', 'source']) || 'application');

    writeTransactionRow_(sheet, targetRow, columns, rowValues);
    sheet.getRange(targetRow, columns.createdAt).setValue(dateTimeText_(createdAt));
    sheet.getRange(targetRow, columns.source).setValue(source);
    sheet.getRange(targetRow, columns.id).setValue(id);
    if (existingRow) {
      updated += 1;
    } else {
      added += 1;
    }
  });

  const deleted = deleteRowsMissingFromSync_(sheet, columns, incomingIds);
  return {
    total: rows.length,
    added,
    updated,
    deleted
  };
}

function deleteTransaction_(sheet, input) {
  const columns = ensureSheetColumns_(sheet);
  const id = String(value_(input, [
    'ID',
    'id',
    'Transaction ID',
    'transaction_id',
    'target_id',
    'targetId'
  ]) || '').trim();
  if (!id) {
    throw new Error('delete_transaction needs ID or target_id.');
  }
  const row = findRowById_(sheet, columns.id, id);
  if (!row) {
    throw new Error(`Transaction not found: ${id}`);
  }
  sheet.deleteRow(row);
  return { id, deleted: 1 };
}

function settleTransaction_(sheet, input) {
  const columns = ensureSheetColumns_(sheet);
  const id = String(value_(input, [
    'ID',
    'id',
    'Transaction ID',
    'transaction_id',
    'target_id',
    'targetId'
  ]) || '').trim();
  if (!id) {
    throw new Error('settle_transaction needs ID or target_id.');
  }
  const row = findRowById_(sheet, columns.id, id);
  if (!row) {
    throw new Error(`Transaction not found: ${id}`);
  }
  sheet.getRange(row, columns.settlementStatus).setValue('settled');
  const source = normalizeSource_(value_(input, ['Source', 'source']) || 'script');
  sheet.getRange(row, columns.source).setValue(source);
  return { id, row, settled: 1 };
}

function listTransactions_(sheet) {
  const columns = ensureSheetColumns_(sheet);
  const lastRow = sheet.getLastRow();
  if (lastRow < FIRST_DATA_ROW) {
    return [];
  }

  const rowCount = lastRow - FIRST_DATA_ROW + 1;
  const width = Math.max(sheet.getLastColumn(), columns.id);
  const values = sheet.getRange(FIRST_DATA_ROW, 1, rowCount, width).getValues();
  const rows = [];

  values.forEach((row, index) => {
    const isEmpty = [
      columns.date,
      columns.status,
      columns.title,
      columns.amountUsd,
      columns.amountLbp,
      columns.category,
      columns.paymentMethod,
      columns.notes
    ].every((column) => String(row[column - 1] || '').trim() === '');
    if (isEmpty) {
      return;
    }

    let id = String(row[columns.id - 1] || '').trim();
    if (!id) {
      id = nextTransactionId_(sheet, columns.id);
      sheet.getRange(FIRST_DATA_ROW + index, columns.id).setValue(id);
    }

    let source = normalizeSource_(row[columns.source - 1] || 'sheet');
    if (!row[columns.source - 1]) {
      sheet.getRange(FIRST_DATA_ROW + index, columns.source).setValue(source);
    }

    let createdAt = normalizeCreatedAt_(row[columns.createdAt - 1]);
    sheet.getRange(FIRST_DATA_ROW + index, columns.createdAt).setValue(dateTimeText_(createdAt));

    rows.push({
      Date: dateText_(row[columns.date - 1]),
      Status: row[columns.status - 1] || '',
      Title: row[columns.title - 1] || '',
      'Amount ($)': number_(row[columns.amountUsd - 1]),
      'Amount (LBP)': number_(row[columns.amountLbp - 1]),
      Category: row[columns.category - 1] || '',
      'Payment Method': row[columns.paymentMethod - 1] || '',
      'Payment Timing': row[columns.paymentTiming - 1] || '',
      Notes: row[columns.notes - 1] || '',
      'Created At': dateTimeText_(createdAt),
      Source: source,
      Wallet: row[columns.wallet - 1] || '',
      'Destination Wallet': row[columns.destinationWallet - 1] || '',
      'Wallet Direction': row[columns.walletDirection - 1] || '',
      'Settlement Status': row[columns.settlementStatus - 1] || '',
      'Linked Transaction ID': row[columns.linkedTransactionId - 1] || '',
      ID: id
    });
  });

  return rows;
}

function buildRowObject_(input) {
  return {
    date: value_(input, ['Date', 'date']),
    status: normalizeStatus_(value_(input, ['Status', 'status', 'type'])),
    title: value_(input, ['Title', 'title', 'description']),
    amountUsd: number_(value_(input, ['Amount ($)', 'Amount USD', 'amount_usd', 'amountUsd'])),
    amountLbp: number_(value_(input, ['Amount (LBP)', 'Amount (LBP )', 'Amount LBP', 'amount_lbp', 'amountLbp'])),
    category: normalizeCategory_(value_(input, ['Category', 'category'])),
    paymentMethod: normalizeWalletLabel_(value_(input, ['Payment Method', 'payment_method', 'paymentMethod'])),
    paymentTiming: normalizePaymentTiming_(value_(input, [
      'Payment Timing',
      'payment_timing',
      'paymentTiming',
      'paid_now',
      'paidNow'
    ])),
    notes: value_(input, ['Notes', 'notes']),
    wallet: normalizeWalletLabel_(value_(input, ['Wallet', 'wallet', 'wallet_id', 'walletId']) ||
      value_(input, ['Payment Method', 'payment_method', 'paymentMethod'])),
    destinationWallet: normalizeWalletLabel_(value_(input, [
      'Destination Wallet',
      'destination_wallet',
      'destination_wallet_id',
      'destinationWalletId'
    ])),
    walletDirection: normalizeWalletDirection_(value_(input, [
      'Wallet Direction',
      'wallet_direction',
      'walletDirection',
      'walletImpact'
    ]), value_(input, ['Status', 'status', 'type'])),
    settlementStatus: normalizeSettlementStatus_(value_(input, [
      'Settlement Status',
      'settlement_status',
      'settlementStatus'
    ])),
    linkedTransactionId: value_(input, [
      'Linked Transaction ID',
      'linked_transaction_id',
      'linkedTransactionId'
    ])
  };
}

function writeTransactionRow_(sheet, row, columns, values) {
  sheet.getRange(row, columns.date).setValue(values.date);
  sheet.getRange(row, columns.status).setValue(values.status);
  sheet.getRange(row, columns.title).setValue(values.title);
  sheet.getRange(row, columns.amountUsd).setValue(values.amountUsd);
  sheet.getRange(row, columns.amountLbp).setValue(values.amountLbp);
  sheet.getRange(row, columns.category).setValue(values.category);
  sheet.getRange(row, columns.paymentMethod).setValue(values.paymentMethod);
  sheet.getRange(row, columns.paymentTiming).setValue(values.paymentTiming);
  sheet.getRange(row, columns.notes).setValue(values.notes);
  sheet.getRange(row, columns.wallet).setValue(values.wallet);
  sheet.getRange(row, columns.destinationWallet).setValue(values.destinationWallet);
  sheet.getRange(row, columns.walletDirection).setValue(values.walletDirection);
  sheet.getRange(row, columns.settlementStatus).setValue(values.settlementStatus);
  sheet.getRange(row, columns.linkedTransactionId).setValue(values.linkedTransactionId);
}

function ensureSheetColumns_(sheet) {
  deleteHeaderColumns_(sheet, ['user']);

  let columns = getColumnMap_(sheet);
  if (!columns.id && !columns.transaction_id) {
    sheet.insertColumnBefore(1);
    sheet.getRange(1, 1).setValue('ID');
  }

  columns = getColumnMap_(sheet);
  const id = columns.id || columns.transaction_id;
  const date = columns.date || createColumnAfter_(sheet, id, 'Date');
  columns = getColumnMap_(sheet);
  const status = columns.status || columns.expense || createColumnAfter_(sheet, columns.date, 'Status');
  columns = getColumnMap_(sheet);
  const title = columns.title || columns.description || createColumnAfter_(sheet, columns.status || columns.expense, 'Title');
  columns = getColumnMap_(sheet);
  const amountUsd = columns.amount || columns.amount_usd || columns.amount_usd_ || createColumnAfter_(sheet, columns.title || columns.description, 'Amount ($)');
  columns = getColumnMap_(sheet);
  const amountLbp = columns.amount_lbp || createColumnAfter_(sheet, columns.amount || columns.amount_usd, 'Amount (LBP)');
  columns = getColumnMap_(sheet);
  const category = columns.category || createColumnAfter_(sheet, columns.amount_lbp, 'Category');
  columns = getColumnMap_(sheet);
  const paymentMethod = columns.payment_method || createColumnAfter_(sheet, columns.category, 'Payment Method');
  columns = getColumnMap_(sheet);
  const paymentTiming = columns.payment_timing || columns.paymenttiming || createColumnAfter_(sheet, columns.payment_method, 'Payment Timing');
  columns = getColumnMap_(sheet);
  const notes = columns.notes || createColumnAfter_(sheet, columns.payment_timing || columns.paymenttiming, 'Notes');
  columns = getColumnMap_(sheet);
  const source = columns.source || createColumnAfter_(sheet, columns.notes, 'Source');
  columns = getColumnMap_(sheet);
  const createdAt = columns.created_at || columns.created || columns.createdat || createColumnAfter_(sheet, columns.source, 'Created At');
  columns = getColumnMap_(sheet);
  const wallet = columns.wallet || columns.wallet_id || createColumnAfter_(sheet, columns.created_at || columns.created || columns.createdat, 'Wallet');
  columns = getColumnMap_(sheet);
  const destinationWallet = columns.destination_wallet || columns.destination_wallet_id || columns.destinationwallet || createColumnAfter_(sheet, columns.wallet || columns.wallet_id, 'Destination Wallet');
  columns = getColumnMap_(sheet);
  const walletDirection = columns.wallet_direction || columns.walletdirection || columns.wallet_impact || createColumnAfter_(sheet, columns.destination_wallet || columns.destination_wallet_id || columns.destinationwallet, 'Wallet Direction');
  columns = getColumnMap_(sheet);
  const settlementStatus = columns.settlement_status || columns.settlementstatus || createColumnAfter_(sheet, columns.wallet_direction || columns.walletdirection || columns.wallet_impact, 'Settlement Status');
  columns = getColumnMap_(sheet);
  const linkedTransactionId = columns.linked_transaction_id || columns.linkedtransactionid || createColumnAfter_(sheet, columns.settlement_status || columns.settlementstatus, 'Linked Transaction ID');

  const refreshed = getColumnMap_(sheet);
  const result = {
    id: refreshed.id || refreshed.transaction_id,
    date: refreshed.date,
    status: refreshed.status || refreshed.expense,
    title: refreshed.title || refreshed.description,
    amountUsd: refreshed.amount || refreshed.amount_usd || refreshed.amount_usd_,
    amountLbp: refreshed.amount_lbp,
    category: refreshed.category,
    paymentMethod: refreshed.payment_method,
    paymentTiming: refreshed.payment_timing || refreshed.paymenttiming,
    notes: refreshed.notes,
    source: refreshed.source,
    createdAt: refreshed.created_at || refreshed.created || refreshed.createdat,
    wallet: refreshed.wallet || refreshed.wallet_id,
    destinationWallet: refreshed.destination_wallet || refreshed.destination_wallet_id || refreshed.destinationwallet,
    walletDirection: refreshed.wallet_direction || refreshed.walletdirection || refreshed.wallet_impact,
    settlementStatus: refreshed.settlement_status || refreshed.settlementstatus,
    linkedTransactionId: refreshed.linked_transaction_id || refreshed.linkedtransactionid
  };

  sheet.getRange(1, result.id).setValue('ID');
  sheet.getRange(1, result.date).setValue('Date');
  sheet.getRange(1, result.status).setValue('Status');
  sheet.getRange(1, result.title).setValue('Title');
  sheet.getRange(1, result.amountUsd).setValue('Amount ($)');
  sheet.getRange(1, result.amountLbp).setValue('Amount (LBP)');
  sheet.getRange(1, result.category).setValue('Category');
  sheet.getRange(1, result.paymentMethod).setValue('Payment Method');
  sheet.getRange(1, result.paymentTiming).setValue('Payment Timing');
  sheet.getRange(1, result.notes).setValue('Notes');
  sheet.getRange(1, result.source).setValue('Source');
  sheet.getRange(1, result.createdAt).setValue('Created At');
  sheet.getRange(1, result.wallet).setValue('Wallet');
  sheet.getRange(1, result.destinationWallet).setValue('Destination Wallet');
  sheet.getRange(1, result.walletDirection).setValue('Wallet Direction');
  sheet.getRange(1, result.settlementStatus).setValue('Settlement Status');
  sheet.getRange(1, result.linkedTransactionId).setValue('Linked Transaction ID');
  return result;
}

function createColumnAfter_(sheet, afterColumn, header) {
  const column = Math.max(1, afterColumn || sheet.getLastColumn());
  sheet.insertColumnAfter(column);
  sheet.getRange(1, column + 1).setValue(header);
  return column + 1;
}

function deleteHeaderColumns_(sheet, normalizedHeaders) {
  const headers = getHeaders_(sheet);
  for (let index = headers.length - 1; index >= 0; index -= 1) {
    if (normalizedHeaders.includes(normalizeHeader_(headers[index]))) {
      sheet.deleteColumn(index + 1);
    }
  }
}

function getColumnMap_(sheet) {
  const headers = getHeaders_(sheet);
  const map = {};
  headers.forEach((header, index) => {
    const normalized = normalizeHeader_(header);
    if (normalized && !map[normalized]) {
      map[normalized] = index + 1;
    }
  });
  return map;
}

function getHeaders_(sheet) {
  const lastColumn = Math.max(sheet.getLastColumn(), 11);
  return sheet.getRange(1, 1, 1, lastColumn).getValues()[0]
    .map((value) => String(value || '').trim());
}

function findRowById_(sheet, idColumn, id) {
  const lastRow = sheet.getLastRow();
  if (lastRow < FIRST_DATA_ROW) {
    return null;
  }

  const ids = sheet.getRange(FIRST_DATA_ROW, idColumn, lastRow - FIRST_DATA_ROW + 1, 1).getValues();
  for (let index = 0; index < ids.length; index += 1) {
    if (String(ids[index][0] || '').trim() === id) {
      return FIRST_DATA_ROW + index;
    }
  }
  return null;
}

function deleteRowsMissingFromSync_(sheet, columns, incomingIds) {
  const lastRow = sheet.getLastRow();
  if (lastRow < FIRST_DATA_ROW) {
    return 0;
  }

  const rowCount = lastRow - FIRST_DATA_ROW + 1;
  const width = Math.max(sheet.getLastColumn(), columns.createdAt, columns.id, columns.linkedTransactionId);
  const values = sheet.getRange(FIRST_DATA_ROW, 1, rowCount, width).getValues();
  let deleted = 0;

  for (let index = values.length - 1; index >= 0; index -= 1) {
    const row = values[index];
    const isEmpty = [
      columns.date,
      columns.status,
      columns.title,
      columns.amountUsd,
      columns.amountLbp,
      columns.category,
      columns.paymentMethod,
      columns.notes
    ].every((column) => String(row[column - 1] || '').trim() === '');
    if (isEmpty) {
      continue;
    }

    const id = String(row[columns.id - 1] || '').trim();
    if (!id || !incomingIds.has(id)) {
      sheet.deleteRow(FIRST_DATA_ROW + index);
      deleted += 1;
    }
  }
  return deleted;
}

function nextTransactionId_(sheet, idColumn) {
  const lastRow = sheet.getLastRow();
  if (lastRow < FIRST_DATA_ROW) {
    return '1';
  }

  const ids = sheet.getRange(FIRST_DATA_ROW, idColumn, lastRow - FIRST_DATA_ROW + 1, 1).getValues();
  let maxNumber = 0;
  ids.forEach((row) => {
    const value = String(row[0] || '').trim();
    const match = /^(?:M)?(\d+)$/i.exec(value);
    if (!match) {
      return;
    }
    const number = Number(match[1]);
    if (Number.isFinite(number) && number > maxNumber) {
      maxNumber = number;
    }
  });
  return String(maxNumber + 1);
}

function applySourceDropdown_(sheet, sourceColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, sourceColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  const rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(SOURCE_VALUES, true)
    .setAllowInvalid(false)
    .build();
  range.setDataValidation(rule);
}

function applyStatusDropdown_(sheet, statusColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, statusColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  const rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(STATUS_VALUES, true)
    .setAllowInvalid(false)
    .build();
  range.setDataValidation(rule);
}

function applySettlementDropdown_(sheet, settlementColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, settlementColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  const rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(SETTLEMENT_VALUES, true)
    .setAllowInvalid(false)
    .build();
  range.setDataValidation(rule);
}

function applyPaymentTimingDropdown_(sheet, paymentTimingColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, paymentTimingColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  const rule = SpreadsheetApp.newDataValidation()
    .requireValueInList(PAYMENT_TIMING_VALUES, true)
    .setAllowInvalid(true)
    .build();
  range.setDataValidation(rule);
}

function applyCreatedAtFormat_(sheet, createdAtColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, createdAtColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  try {
    range.setNumberFormat('yyyy-mm-dd hh:mm:ss');
  } catch (error) {
    Logger.log(`Created At format skipped: ${error}`);
  }
}

function applySourceColors_(sheet, sourceColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, sourceColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  const a1 = range.getA1Notation();
  const letter = columnLetter_(sourceColumn);
  const existingRules = sheet.getConditionalFormatRules()
    .filter((rule) => !rule.getRanges().some((ruleRange) => ruleRange.getA1Notation() === a1));
  const colorRules = [
    ['application', '#DCFCE7', '#166534'],
    ['Google Sheet', '#DBEAFE', '#1D4ED8'],
    ['script', '#F3E8FF', '#7E22CE']
  ].map(([value, background, foreground]) =>
    SpreadsheetApp.newConditionalFormatRule()
      .whenFormulaSatisfied(`=$${letter}${FIRST_DATA_ROW}="${value}"`)
      .setBackground(background)
      .setFontColor(foreground)
      .setRanges([range])
      .build()
  );
  sheet.setConditionalFormatRules([...existingRules, ...colorRules]);
}

function applyStatusColors_(sheet, statusColumn) {
  const range = sheet.getRange(FIRST_DATA_ROW, statusColumn, sheet.getMaxRows() - FIRST_DATA_ROW + 1, 1);
  const a1 = range.getA1Notation();
  const letter = columnLetter_(statusColumn);
  const existingRules = sheet.getConditionalFormatRules()
    .filter((rule) => !rule.getRanges().some((ruleRange) => ruleRange.getA1Notation() === a1));
  const colorRules = [
    ['Income', '#DCFCE7', '#166534'],
    ['Expense', '#FEE2E2', '#991B1B'],
    ['Credit', '#FEF3C7', '#92400E'],
    ['Debt', '#EDE9FE', '#5B21B6'],
    ['Transfer', '#DBEAFE', '#1D4ED8']
  ].map(([value, background, foreground]) =>
    SpreadsheetApp.newConditionalFormatRule()
      .whenFormulaSatisfied(`=$${letter}${FIRST_DATA_ROW}="${value}"`)
      .setBackground(background)
      .setFontColor(foreground)
      .setRanges([range])
      .build()
  );
  sheet.setConditionalFormatRules([...existingRules, ...colorRules]);
}

function getSheet_() {
  const spreadsheet = SpreadsheetApp.getActiveSpreadsheet();
  if (!spreadsheet) {
    throw new Error('Active spreadsheet not found. Open the script from Extensions > Apps Script inside the Google Sheet.');
  }

  if (SHEET_NAME.trim()) {
    const namedSheet = spreadsheet.getSheetByName(SHEET_NAME.trim());
    if (namedSheet) {
      return namedSheet;
    }
  }

  const sheets = spreadsheet.getSheets();
  for (const sheet of sheets) {
    const headers = getHeaders_(sheet).map(normalizeHeader_);
    const hasMainHeaders =
      headers.includes('date') &&
      headers.includes('status') &&
      headers.includes('title');
    if (hasMainHeaders) {
      return sheet;
    }
  }

  if (sheets.length > 0) {
    return sheets[0];
  }

  throw new Error('No sheet tabs found in this spreadsheet.');
}

function normalizeStatus_(value) {
  const text = String(value || '').trim().toLowerCase();
  if (text.includes('credit') || text.includes('receivable') || text.includes('reserve')) return 'Credit';
  if (text.includes('debt') || text.includes('payable')) return 'Debt';
  if (text.includes('transfer')) return 'Transfer';
  if (text.includes('income')) return 'Income';
  return 'Expense';
}

function normalizeSettlementStatus_(value) {
  const text = String(value || '').trim().toLowerCase();
  if (text === 'settled') return 'settled';
  if (text === 'partial') return 'partial';
  return 'open';
}

function normalizePaymentTiming_(value) {
  const text = String(value || '').trim().toLowerCase();
  if (!text) return '';
  if (text === 'false' || text.includes('credit') || text.includes('later')) {
    return 'On Credit';
  }
  return 'Paid Now';
}

function normalizeWalletLabel_(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';
  const key = raw.toLowerCase().replace(/[^a-z0-9]+/g, '');
  if (key.includes('whish') || key.includes('wesh') || key.includes('wish')) {
    return 'Whish Money';
  }
  if (key === 'mywallet' || key === 'wallet' || key === 'cash') {
    return 'Cash';
  }
  return normalizeText_(raw);
}

function normalizeCategory_(value) {
  const raw = String(value || '').trim();
  if (!raw) return '';
  const key = raw.toLowerCase().replace(/[^a-z0-9]+/g, '');
  const aliases = {
    masroufbayt: 'Home expenses',
    masrofbayt: 'Home expenses',
    homeexpense: 'Home expenses',
    homeexpenses: 'Home expenses',
    dyefe: 'Hospitality',
    diyafe: 'Hospitality',
    dyoune: 'Debt payments',
    dyoun: 'Debt payments',
    dion: 'Debt payments',
    eshtiraket: 'Subscriptions',
    ishtiraket: 'Subscriptions',
    na2rashe: 'Small purchases',
    nakrashe: 'Small purchases',
    incomeinternet: 'Internet income',
    incomezougeib: 'Zougeib income',
    incomezougaib: 'Zougeib income',
    incomeother: 'Other income',
    incomeaboudi: 'Aboudi income',
    wishmoney: 'Whish Money',
    whishmoney: 'Whish Money',
    weshmoney: 'Whish Money',
    wishtopup: 'Whish top up',
    whishtopup: 'Whish top up',
    wishreceived: 'Whish received',
    whishreceived: 'Whish received',
    wishtransfer: 'Whish transfer',
    whishtransfer: 'Whish transfer',
    wishexchange: 'Whish exchange',
    whishexchange: 'Whish exchange'
  };
  return aliases[key] || normalizeText_(raw);
}

function normalizeText_(value) {
  return String(value || '')
    .trim()
    .replace(/\bwhish\s+money\b/gi, 'Whish Money')
    .replace(/\bwesh\s+money\b/gi, 'Whish Money')
    .replace(/\bwish\s+money\b/gi, 'Whish Money')
    .replace(/\bwhish\b/gi, 'Whish')
    .replace(/\bwesh\b/gi, 'Whish');
}

function normalizeWalletDirection_(value, status) {
  const parsed = Number(String(value || '').trim());
  if (Number.isFinite(parsed) && parsed >= -1 && parsed <= 1) {
    return parsed;
  }
  const normalizedStatus = normalizeStatus_(status);
  if (normalizedStatus === 'Income' || normalizedStatus === 'Debt') return 1;
  if (normalizedStatus === 'Expense' || normalizedStatus === 'Credit') return -1;
  return 0;
}

function normalizeSource_(value) {
  const text = String(value || '').trim().toLowerCase();
  if (text === 'script' || text === 'gemini' || text === 'manual') {
    return 'script';
  }
  if (text === 'google sheet' || text === 'sheet') {
    return 'Google Sheet';
  }
  return 'application';
}

function normalizeCreatedAt_(value) {
  if (value instanceof Date) {
    return value.getFullYear() < 2000 ? new Date() : value;
  }
  const text = String(value || '').trim();
  if (!text) {
    return new Date();
  }
  if (text === '0' || text === '1899-12-30' || text.startsWith('1899-12-30')) {
    return new Date();
  }
  const parsed = new Date(text.replace(' ', 'T'));
  if (!Number.isNaN(parsed.getTime())) {
    return parsed.getFullYear() < 2000 ? new Date() : parsed;
  }
  return new Date();
}

function normalizeHeader_(header) {
  return String(header || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '');
}

function number_(value) {
  if (value === null || value === undefined || value === '') return 0;
  const clean = String(value).replace(/[$,LBP\s]/gi, '');
  const parsed = Number(clean);
  return Number.isFinite(parsed) ? parsed : 0;
}

function value_(input, keys) {
  for (const key of keys) {
    if (Object.prototype.hasOwnProperty.call(input, key)) {
      const value = input[key];
      return value === null || value === undefined ? '' : value;
    }
  }
  return '';
}

function dateText_(value) {
  if (value instanceof Date) {
    return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd');
  }
  return String(value || '').trim();
}

function dateTimeText_(value) {
  if (value instanceof Date) {
    if (value.getFullYear() < 2000) {
      return Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');
    }
    return Utilities.formatDate(value, Session.getScriptTimeZone(), 'yyyy-MM-dd HH:mm:ss');
  }
  return dateTimeText_(normalizeCreatedAt_(value));
}

function columnLetter_(column) {
  let temp = column;
  let letter = '';
  while (temp > 0) {
    const modulo = (temp - 1) % 26;
    letter = String.fromCharCode(65 + modulo) + letter;
    temp = Math.floor((temp - modulo) / 26);
  }
  return letter;
}

function parsePayload_(e) {
  const contents = e && e.postData && e.postData.contents ? e.postData.contents : '{}';
  return JSON.parse(contents);
}

function json_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}
