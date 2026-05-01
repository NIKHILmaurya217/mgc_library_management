// ============================================================
// RFID Library Attendance System - Google Apps Script
// PRODUCTION VERSION v4.0 (Merged with ESP32 v9.0 Compatibility)
// ============================================================

// ============================================================
// CONFIGURATION
// ============================================================
const SPREADSHEET_ID = '';
const STUDENT_SHEET = 'Students';
const FEE_SHEET = 'Student Fees';
const TIMEZONE = 'Asia/Kolkata';
const REPORT_EMAIL = '';
const REPORT_EMAIL2 = '';
const SEND_TIME_HOUR = 22;

// Column indices (0-based)
const S = { UID: 0, ROLL: 1, NAME: 2, CLASS: 3, PHONE: 4, ENROLLED: 5, PHOTO: 6 };
const A = { ROLL: 0, NAME: 1, CLASS: 2, ENTRY: 3, EXIT: 4, DURATION: 5, STATUS: 6 };
const F = { UID: 0, ROLL: 1, NAME: 2, CLASS: 3, TOTAL_FEE: 4, MONTHS_START: 5 };

// Fee months list
const FEE_MONTHS = [
    'Jan 2026', 'Feb 2026', 'Mar 2026', 'Apr 2026',
    'May 2026', 'Jun 2026', 'Jul 2026', 'Aug 2026',
    'Sep 2026', 'Oct 2026', 'Nov 2026', 'Dec 2026'
];

let _ss = null;
function getSS() { if (!_ss) _ss = SpreadsheetApp.openById(SPREADSHEET_ID); return _ss; }
function getSSS() { return SpreadsheetApp.openById(SPREADSHEET_ID); }


// ============================================================
// ENTRY POINTS
// ============================================================
function doGet(e) {
    try {
        const p = e.parameter;
        const uid = p.uid ? p.uid.toUpperCase().trim() : null;
        const mode = p.mode || null;
        const ts = p.ts || null;

        // ESP32 sends duplicate "action" keys (e.g. action=attendance & action=Entry)
        // We must use e.parameters.action to capture both in an array
        const actions = e.parameters.action || [];
        const action = p.action || null;

        // ✅ ESP32 v9 Endpoints (New Lazy Sync)
        if (actions.includes('upsert_student')) return upsertStudentV9(p);
        if (actions.includes('attendance')) return markAttendanceV9(p, actions);

        // Web Dashboard API endpoints
        if (action === 'dashboard') return getDashboardStats();
        if (action === 'students') return getStudentList();
        if (action === 'fees') return getFeeSheet();
        if (action === 'markfee') return markFee(p);
        if (action === 'feestatus') return getFeeStatus(p.roll);
        if (action === 'search') return searchStudent(p.q || '');
        if (action === 'uploadphoto') return json(uploadStudentPhoto(p.roll, p.photo, p.mime));

        // Fallback/Legacy endpoints
        if (!uid) return txt('RFID Attendance System v4.0 (ESP32 v9 Sync) running!');
        if (mode === 'enroll') return handleEnroll(uid);
        return handleScan(uid, ts);

    } catch (err) {
        return json({ status: 'error', message: err.toString() });
    }
}

function doPost(e) { /* (Keep your exact same doPost code here from v4.0) */
    try {
        let d = {};
        if (e?.postData?.type === 'application/x-www-form-urlencoded') {
            d = e.parameter;
        } else if (e?.postData?.contents) {
            d = JSON.parse(e.postData.contents);
        } else {
            return json({ status: 'error', message: 'No data' });
        }

        if (d.action === 'uploadphoto') {
            return json(uploadStudentPhoto(d.roll, d.photo, d.mime));
        }

        const uid = d.uid ? d.uid.toString().toUpperCase().trim() : null;
        if (!uid) return json({ status: 'error', message: 'No UID' });
        if (d.mode === 'enroll') return handleEnroll(uid);
        return handleScan(uid, d.offline_timestamp || null);
    } catch (err) {
        return json({ status: 'error', message: err.toString() });
    }
}


// ============================================================
// ESP32 V9 LAZY SYNC HANDLERS
// ============================================================

// Auto-add new students
function upsertStudentV9(p) {
    try {
        const ss = getSSS();
        const stuSheet = ss.getSheetByName(STUDENT_SHEET);
        const uid = p.uid ? p.uid.toUpperCase().trim() : '';
        const name = p.name || '';
        const roll = p.roll || '';
        const cls = p.cls || '';
        const phone = p.phone || '';

        // Stop if UID already here
        if (findStudent(stuSheet, uid)) return txt("Student exists");

        const now = Utilities.formatDate(new Date(), TIMEZONE, 'yyyy-MM-dd HH:mm:ss');
        stuSheet.appendRow([uid, roll, name, cls, phone, now, '']);
        syncStudentsToFeeSheet(); // Keep fees updated

        return txt("Student Added");
    } catch (err) { return txt(err.toString()); }
}

// Map ESP32 "Entry/Exit" commands into your structured Day-Sheets 
function markAttendanceV9(p, actions) {
    try {
        const uid = p.uid ? p.uid.toUpperCase().trim() : '';
        // Extract whether ESP32 declared this an Entry or Exit
        const scanType = actions.find(a => a === 'Entry' || a === 'Exit') || 'Entry';

        // Parse timestamp (Extract 'HH:mm:ss' from 'YYYY-MM-DD HH:mm:ss')
        const tsStr = p.ts || getTime();
        const now = tsStr.includes(' ') ? tsStr.split(' ')[1] : tsStr;

        const ss = getSSS();
        const daySheet = getDaySheet(ss);
        const stuSheet = ss.getSheetByName(STUDENT_SHEET);

        // Find info
        const student = findStudent(stuSheet, uid) || { name: p.name, roll: p.roll, cls: p.cls };
        const existing = findTodayRow(daySheet, student.roll);

        if (scanType === 'Entry') {
            if (!existing) {
                daySheet.appendRow([student.roll, student.name, student.cls, now, '', '', 'Inside']);
                daySheet.getRange(daySheet.getLastRow(), 1, 1, 7).setBackground('#e8f5e9'); // Green
            } else {
                const row = existing.row; // Re-entry handling
                daySheet.getRange(row, A.EXIT + 1).setValue('');
                daySheet.getRange(row, A.DURATION + 1).setValue('');
                daySheet.getRange(row, A.STATUS + 1).setValue('Re-entered');
                daySheet.getRange(row, 1, 1, 7).setBackground('#fff9c4'); // Yellow
            }
        } else if (scanType === 'Exit') {
            if (existing) {
                const row = existing.row;
                const entryRaw = daySheet.getRange(row, A.ENTRY + 1).getValue();
                const entryStr = entryRaw instanceof Date ? Utilities.formatDate(entryRaw, TIMEZONE, 'HH:mm:ss') : entryRaw.toString();
                const dur = calcDur(entryStr, now);

                daySheet.getRange(row, A.EXIT + 1).setValue(now);
                daySheet.getRange(row, A.DURATION + 1).setValue(dur);
                daySheet.getRange(row, A.STATUS + 1).setValue('Left');
                daySheet.getRange(row, 1, 1, 7).setBackground('#e3f2fd'); // Blue
            } else {
                // Edge case: Scanned Exit but no Entry recorded today
                daySheet.appendRow([student.roll, student.name, student.cls, '', now, '', 'Left']);
            }
        }
        return txt('Attendance Logged');
    } catch (err) { return txt(err.toString()); }
}


// ============================================================
// EVERYTHING ELSE REMAINS UNCHANGED (Kept precisely from your v4.0)
// ============================================================

function handleScan(uid, offlineTs) { /* (Your original code) */
    const ss = getSS();
    const stuSheet = ss.getSheetByName(STUDENT_SHEET);
    const student = findStudent(stuSheet, uid);
    if (!student) return json({ status: 'unknown', message: 'Card not registered', uid });
    const daySheet = getDaySheet(ss);
    const now = offlineTs ? (offlineTs.includes(' ') ? offlineTs.split(' ')[1] : offlineTs) : getTime();
    const existing = findTodayRow(daySheet, student.roll);
    if (!existing) {
        daySheet.appendRow([student.roll, student.name, student.cls, now, '', '', 'Inside']);
        const r = daySheet.getLastRow();
        daySheet.getRange(r, 1, 1, 7).setBackground('#e8f5e9');
        return json({ status: 'success', type: 'Entry', name: student.name, roll: student.roll, studentClass: student.cls, time: now });
    } else {
        const row = existing.row;
        const exitVal = daySheet.getRange(row, A.EXIT + 1).getValue();
        const statusVal = daySheet.getRange(row, A.STATUS + 1).getValue();
        if (exitVal === '') {
            const entryRaw = existing.entry;
            const entryStr = entryRaw instanceof Date ? Utilities.formatDate(entryRaw, TIMEZONE, 'HH:mm:ss') : entryRaw.toString();
            const dur = calcDur(entryStr, now);
            daySheet.getRange(row, A.EXIT + 1).setValue(now);
            daySheet.getRange(row, A.DURATION + 1).setValue(dur);
            daySheet.getRange(row, A.STATUS + 1).setValue('Left');
            daySheet.getRange(row, 1, 1, 7).setBackground('#e3f2fd');
            return json({ status: 'success', type: 'Exit', name: student.name, roll: student.roll, studentClass: student.cls, time: now, duration: dur });
        } else if (statusVal === 'Re-entered') {
            const entryRaw2 = daySheet.getRange(row, A.ENTRY + 1).getValue();
            const entryStr2 = entryRaw2 instanceof Date ? Utilities.formatDate(entryRaw2, TIMEZONE, 'HH:mm:ss') : entryRaw2.toString();
            const dur2 = calcDur(entryStr2, now);
            daySheet.getRange(row, A.EXIT + 1).setValue(now);
            daySheet.getRange(row, A.DURATION + 1).setValue(dur2);
            daySheet.getRange(row, A.STATUS + 1).setValue('Left');
            daySheet.getRange(row, 1, 1, 7).setBackground('#e3f2fd');
            return json({ status: 'success', type: 'Exit', name: student.name, roll: student.roll, studentClass: student.cls, time: now, duration: dur2 });
        } else {
            daySheet.getRange(row, A.EXIT + 1).setValue('');
            daySheet.getRange(row, A.DURATION + 1).setValue('');
            daySheet.getRange(row, A.STATUS + 1).setValue('Re-entered');
            daySheet.getRange(row, 1, 1, 7).setBackground('#fff9c4');
            return json({ status: 'success', type: 'Re-entry', name: student.name, roll: student.roll, studentClass: student.cls, time: now });
        }
    }
}

function handleEnroll(uid) { /* (Your original code) */
    const ss = getSS();
    const stuSheet = ss.getSheetByName(STUDENT_SHEET);
    const existing = findStudent(stuSheet, uid);
    if (existing) return json({ status: 'already_enrolled', message: 'Already registered: ' + existing.name, name: existing.name });
    const now = Utilities.formatDate(new Date(), TIMEZONE, 'yyyy-MM-dd HH:mm:ss');
    stuSheet.appendRow([uid, '', 'NEW STUDENT - Fill details', '', '', now]);
    syncStudentsToFeeSheet();
    return json({ status: 'enrolled', message: 'UID added. Fill Name, Roll, Class, Phone in Students sheet.', uid });
}

function refreshFeeSheetStudent(roll, name, cls) { /* (Your original code) */
    const ss = getSSS();
    const feeSheet = ss.getSheetByName(FEE_SHEET);
    if (!feeSheet) return;
    const feeData = feeSheet.getDataRange().getValues();
    for (let i = 1; i < feeData.length; i++) {
        if (feeData[i][F.ROLL].toString() === roll.toString()) {
            feeSheet.getRange(i + 1, F.NAME + 1).setValue(name);
            feeSheet.getRange(i + 1, F.CLASS + 1).setValue(cls);
            return;
        }
    }
}

function getDashboardStats() { /* (Your original code) */
    try {
        const ss = getSSS();
        const label = Utilities.formatDate(new Date(), TIMEZONE, 'dd-MMM-yyyy');
        const today = ss.getSheetByName(label);
        const stuSheet = ss.getSheetByName(STUDENT_SHEET);
        const feeSheet = ss.getSheetByName(FEE_SHEET);
        const stuData = stuSheet.getDataRange().getValues();
        const students = Math.max(0, stuData.length - 1);
        const currentMonth = Utilities.formatDate(new Date(), TIMEZONE, 'MMM yyyy');
        let feePaid = 0, feePending = 0;
        if (feeSheet) {
            const feeData = feeSheet.getDataRange().getValues();
            const headers = feeData[0].map(h => {
                if (!h) return '';
                if (h instanceof Date) return Utilities.formatDate(h, TIMEZONE, 'MMM yyyy');
                return h.toString();
            });
            const monthCol = headers.indexOf(currentMonth);
            if (monthCol >= 0) {
                for (let i = 1; i < feeData.length; i++) {
                    if (!feeData[i][F.ROLL]) continue;
                    const val = feeData[i][monthCol] ? feeData[i][monthCol].toString() : 'PENDING';
                    if (val.startsWith('PAID')) feePaid++;
                    else if (val.startsWith('PARTIAL')) feePaid++;
                    else feePending++;
                }
            }
        }
        let total = 0, inside = 0, left = 0, reentry = 0;
        let recent = [];
        if (today) {
            const last = today.getLastRow();
            if (last >= 3) {
                const data = today.getRange(3, 1, last - 2, 7).getValues();
                data.forEach(r => {
                    if (!r[0]) return;
                    total++;
                    const status = r[6] ? r[6].toString() : '';
                    if (status === 'Inside') inside++;
                    else if (status === 'Left') left++;
                    else if (status === 'Re-entered') { reentry++; inside++; }
                    const fmt = val => {
                        if (!val) return '';
                        if (val instanceof Date) return Utilities.formatDate(val, TIMEZONE, 'HH:mm:ss');
                        return val.toString();
                    };
                    recent.push({ roll: r[0] ? r[0].toString() : '', name: r[1] ? r[1].toString() : '', cls: r[2] ? r[2].toString() : '', entry: fmt(r[3]), exit: fmt(r[4]), dur: r[5] ? r[5].toString() : '', status: status || 'Inside' });
                });
                recent = recent.reverse().slice(0, 8);
            }
        }
        return json({ total, inside, left, reentry, students, feePaid, feePending, currentMonth, date: label, recent });
    } catch (err) { return json({ error: err.toString() }); }
}

function getStudentList() { /* (Your original code) */
    try {
        const ss = getSSS();
        const stuSheet = ss.getSheetByName(STUDENT_SHEET);
        const feeSheet = ss.getSheetByName(FEE_SHEET);
        const data = stuSheet.getDataRange().getValues();
        const currentMonth = Utilities.formatDate(new Date(), TIMEZONE, 'MMM yyyy');
        const feeStatus = {};
        if (feeSheet) {
            const feeData = feeSheet.getDataRange().getValues();
            const headers = feeData[0].map(h => {
                if (!h) return '';
                if (h instanceof Date) return Utilities.formatDate(h, TIMEZONE, 'MMM yyyy');
                return h.toString();
            });
            const monthCol = headers.indexOf(currentMonth);
            if (monthCol >= 0) {
                for (let i = 1; i < feeData.length; i++) {
                    const roll = feeData[i][F.ROLL] ? feeData[i][F.ROLL].toString() : '';
                    const val = feeData[i][monthCol] ? feeData[i][monthCol].toString() : 'PENDING';
                    if (roll) feeStatus[roll] = val;
                }
            }
        }
        const students = [];
        for (let i = 1; i < data.length; i++) {
            if (!data[i][S.UID]) continue;
            const roll = data[i][S.ROLL] ? data[i][S.ROLL].toString() : '';
            students.push({
                uid: data[i][S.UID] ? data[i][S.UID].toString() : '', roll,
                name: data[i][S.NAME] ? data[i][S.NAME].toString() : '',
                cls: data[i][S.CLASS] ? data[i][S.CLASS].toString() : '',
                phone: data[i][S.PHONE] ? data[i][S.PHONE].toString() : '',
                enrolled: data[i][S.ENROLLED] ? data[i][S.ENROLLED].toString() : '',
                photo: data[i][S.PHOTO]?.toString() || '',
                feeStatus: feeStatus[roll] || 'PENDING'
            });
        }
        return json({ students, currentMonth });
    } catch (err) { return json({ error: err.toString() }); }
}

function getFeeSheet() { /* (Your original code) */
    try {
        const ss = getSSS();
        const feeSheet = ss.getSheetByName(FEE_SHEET);
        if (!feeSheet) return json({ error: 'Fee sheet not found. Run setupFeeSheet() first.' });
        const data = feeSheet.getDataRange().getValues();
        const headers = data[0];
        const months = headers.slice(F.MONTHS_START).map(m => {
            if (!m) return '';
            if (m instanceof Date) return Utilities.formatDate(m, TIMEZONE, 'MMM yyyy');
            return m.toString();
        });
        const rows = [];
        for (let i = 1; i < data.length; i++) {
            if (!data[i][F.ROLL]) continue;
            const payments = {};
            months.forEach((m, idx) => { payments[m] = data[i][F.MONTHS_START + idx] ? data[i][F.MONTHS_START + idx].toString() : 'PENDING'; });
            rows.push({
                uid: data[i][F.UID] ? data[i][F.UID].toString() : '', roll: data[i][F.ROLL] ? data[i][F.ROLL].toString() : '',
                name: data[i][F.NAME] ? data[i][F.NAME].toString() : '', cls: data[i][F.CLASS] ? data[i][F.CLASS].toString() : '',
                totalFee: data[i][F.TOTAL_FEE] ? data[i][F.TOTAL_FEE].toString() : '', payments
            });
        }
        return json({ months, rows });
    } catch (err) { return json({ error: err.toString() }); }
}

function markFee(p) { /* (Your original code) */
    try {
        const roll = p.roll || '';
        const month = p.month || '';
        const status = p.status || 'PAID';
        const receipt = p.receipt || '';
        const amount = p.amount || '';
        if (!roll || !month) return json({ status: 'error', message: 'Roll number and month required' });
        const ss = getSSS();
        const feeSheet = ss.getSheetByName(FEE_SHEET);
        if (!feeSheet) return json({ status: 'error', message: 'Fee sheet not found' });
        const data = feeSheet.getDataRange().getValues();
        const headers = data[0];
        const monthCol = headers.indexOf(month);
        if (monthCol < 0) return json({ status: 'error', message: 'Month not found: ' + month });
        let studentRow = -1;
        for (let i = 1; i < data.length; i++) {
            if (data[i][F.ROLL] && data[i][F.ROLL].toString() === roll) { studentRow = i + 1; break; }
        }
        if (studentRow < 0) return json({ status: 'error', message: 'Student not found: Roll ' + roll });
        let cellValue = status;
        if (status === 'PAID' && receipt) cellValue = 'PAID:' + receipt;
        if (status === 'PARTIAL' && amount) cellValue = 'PARTIAL:' + amount;
        feeSheet.getRange(studentRow, monthCol + 1).setValue(cellValue);
        const cell = feeSheet.getRange(studentRow, monthCol + 1);
        if (status === 'PAID') cell.setBackground('#c8e6c9');
        if (status === 'PARTIAL') cell.setBackground('#fff9c4');
        if (status === 'PENDING') cell.setBackground('#ffcdd2');
        return json({ status: 'success', message: 'Fee updated for Roll ' + roll + ' — ' + month + ': ' + cellValue, roll, month, value: cellValue });
    } catch (err) { return json({ status: 'error', message: err.toString() }); }
}

function getFeeStatus(roll) { /* (Your original code) */
    try {
        if (!roll) return json({ error: 'Roll number required' });
        const ss = getSSS();
        const feeSheet = ss.getSheetByName(FEE_SHEET);
        if (!feeSheet) return json({ error: 'Fee sheet not found' });
        const data = feeSheet.getDataRange().getValues();
        const headers = data[0];
        const months = headers.slice(F.MONTHS_START).map(m => {
            if (!m) return '';
            if (m instanceof Date) return Utilities.formatDate(m, TIMEZONE, 'MMM yyyy');
            return m.toString();
        });
        for (let i = 1; i < data.length; i++) {
            if (data[i][F.ROLL] && data[i][F.ROLL].toString() === roll) {
                const payments = {};
                months.forEach((m, idx) => { payments[m] = data[i][F.MONTHS_START + idx] ? data[i][F.MONTHS_START + idx].toString() : 'PENDING'; });
                return json({ roll, name: data[i][F.NAME] ? data[i][F.NAME].toString() : '', totalFee: data[i][F.TOTAL_FEE] ? data[i][F.TOTAL_FEE].toString() : '', payments });
            }
        }
        return json({ error: 'Student not found' });
    } catch (err) { return json({ error: err.toString() }); }
}

function searchStudent(query) { /* (Your original code) */
    try {
        if (!query || query.trim() === '') return json({ results: [] });
        query = query.toString().toLowerCase().trim();
        const ss = getSSS();
        const stuSheet = ss.getSheetByName(STUDENT_SHEET);
        const feeSheet = ss.getSheetByName(FEE_SHEET);
        const label = Utilities.formatDate(new Date(), TIMEZONE, 'dd-MMM-yyyy');
        const daySheet = ss.getSheetByName(label);
        const todayMap = {};
        if (daySheet && daySheet.getLastRow() >= 3) {
            const dayData = daySheet.getRange(3, 1, daySheet.getLastRow() - 2, 7).getValues();
            dayData.forEach(r => {
                if (!r[0]) return;
                const fmt = v => {
                    if (!v) return '';
                    if (v instanceof Date) return Utilities.formatDate(v, TIMEZONE, 'HH:mm:ss');
                    return v.toString();
                };
                todayMap[r[0].toString()] = { entry: fmt(r[3]), exit: fmt(r[4]), duration: r[5] ? r[5].toString() : '', status: r[6] ? r[6].toString() : '' };
            });
        }
        const feeMap = {};
        if (feeSheet) {
            const feeData = feeSheet.getDataRange().getValues();
            const headers = feeData[0];
            const months = headers.slice(F.MONTHS_START);
            for (let i = 1; i < feeData.length; i++) {
                const roll = feeData[i][F.ROLL] ? feeData[i][F.ROLL].toString() : '';
                if (!roll) continue;
                const payments = {};
                months.forEach((m, idx) => { payments[m] = feeData[i][F.MONTHS_START + idx] ? feeData[i][F.MONTHS_START + idx].toString() : 'PENDING'; });
                feeMap[roll] = { totalFee: feeData[i][F.TOTAL_FEE] ? feeData[i][F.TOTAL_FEE].toString() : '', payments };
            }
        }
        const stuData = stuSheet.getDataRange().getValues();
        const results = [];
        const currentMonth = Utilities.formatDate(new Date(), TIMEZONE, 'MMM yyyy');
        for (let i = 1; i < stuData.length; i++) {
            const r = stuData[i];
            const uid = r[S.UID] ? r[S.UID].toString() : '';
            const roll = r[S.ROLL] ? r[S.ROLL].toString() : '';
            const name = r[S.NAME] ? r[S.NAME].toString() : '';
            const cls = r[S.CLASS] ? r[S.CLASS].toString() : '';
            const phone = r[S.PHONE] ? r[S.PHONE].toString() : '';
            if (!(name.toLowerCase().includes(query) || roll.toLowerCase().includes(query) || uid.toLowerCase().includes(query) || cls.toLowerCase().includes(query) || phone.includes(query))) continue;
            const fee = feeMap[roll] || { totalFee: '', payments: {} };
            const paidCount = Object.values(fee.payments).filter(v => v.startsWith('PAID')).length;
            const pendingCount = Object.values(fee.payments).filter(v => v === 'PENDING').length;
            const thisMonthFee = fee.payments[currentMonth] || 'PENDING';
            results.push({
                uid, roll, name, cls, phone, photo: r[S.PHOTO]?.toString() || '', enrolled: r[S.ENROLLED] ? r[S.ENROLLED].toString() : '',
                today: todayMap[roll] || null, fee: { totalFee: fee.totalFee, currentMonth, thisMonthFee, paidCount, pendingCount, history: fee.payments }
            });
            if (results.length >= 10) break;
        }
        return json({ results });
    } catch (err) { return json({ results: [], error: err.toString() }); }
}

function getDaySheet(ss) { /* (Your original code) */
    const name = Utilities.formatDate(new Date(), TIMEZONE, 'dd-MMM-yyyy');
    let sheet = ss.getSheetByName(name);
    if (!sheet) {
        sheet = ss.insertSheet(name);
        buildDayHeader(sheet, name);
    }
    return sheet;
}

function buildDayHeader(sheet, label) { /* (Your original code) */
    sheet.getRange(1, 1, 1, 7).merge().setValue('Library Attendance — ' + label).setBackground('#1a237e').setFontColor('#fff').setFontSize(13).setFontWeight('bold').setHorizontalAlignment('center');
    sheet.setRowHeight(1, 36);
    const h = ['Roll No', 'Name', 'Class', 'Entry Time', 'Exit Time', 'Duration', 'Status'];
    sheet.getRange(2, 1, 1, 7).setValues([h]).setBackground('#283593').setFontColor('#fff').setFontWeight('bold').setHorizontalAlignment('center');
    sheet.setRowHeight(2, 28);
    [90, 160, 100, 100, 100, 90, 100].forEach((w, i) => sheet.setColumnWidth(i + 1, w));
    sheet.setFrozenRows(2);
}

function findStudent(sheet, uid) { /* (Your original code) */
    const data = sheet.getDataRange().getValues();
    for (let i = 1; i < data.length; i++) {
        if (data[i][S.UID]?.toString().toUpperCase().trim() === uid) {
            return { roll: data[i][S.ROLL]?.toString() || '', name: data[i][S.NAME]?.toString() || '', cls: data[i][S.CLASS]?.toString() || '', photo: data[i][S.PHOTO]?.toString() || '' };
        }
    }
    return null;
}

function findTodayRow(sheet, roll) { /* (Your original code) */
    const last = sheet.getLastRow();
    if (last < 3) return null;
    const data = sheet.getRange(3, 1, last - 2, 7).getValues();
    for (let i = 0; i < data.length; i++) {
        if (data[i][A.ROLL]?.toString().trim() === roll?.toString().trim()) {
            return { row: i + 3, entry: data[i][A.ENTRY] instanceof Date ? Utilities.formatDate(data[i][A.ENTRY], TIMEZONE, 'HH:mm:ss') : data[i][A.ENTRY].toString() };
        }
    }
    return null;
}

function calcDur(entryVal, exitStr) { /* (Your original code) */
    try {
        const today = Utilities.formatDate(new Date(), TIMEZONE, 'yyyy-MM-dd');
        let entryMs, exitMs;
        entryMs = entryVal instanceof Date ? entryVal.getTime() : new Date(today + ' ' + entryVal).getTime();
        exitMs = exitStr instanceof Date ? exitStr.getTime() : new Date(today + ' ' + exitStr).getTime();
        const diff = exitMs - entryMs;
        if (isNaN(diff) || diff <= 0) return 'N/A';
        const m = Math.floor(diff / 60000);
        const h = Math.floor(m / 60);
        return h > 0 ? `${h}h ${m % 60}m` : `${m}m`;
    } catch (_) { return 'N/A'; }
}

function getTime() { /* (Your original code) */
    return Utilities.formatDate(new Date(), TIMEZONE, 'HH:mm:ss');
}

function json(obj) { /* (Your original code) */
    return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.TEXT);
}

function txt(msg) { /* (Your original code) */
    return ContentService.createTextOutput(msg);
}

function setupSheets() { /* (Your original code) */
    const ss = getSSS();
    let s = ss.getSheetByName(STUDENT_SHEET);
    if (!s) s = ss.insertSheet(STUDENT_SHEET);
    const h = ['RFID UID', 'Roll Number', 'Name', 'Class/Course', 'Phone', 'Enrolled On'];
    s.getRange(1, 1, 1, 6).setValues([h]).setBackground('#1a237e').setFontColor('#fff').setFontWeight('bold');
    [130, 100, 160, 110, 120, 150].forEach((w, i) => s.setColumnWidth(i + 1, w));
    s.setFrozenRows(1);
    setupFeeSheet();
    getDaySheet(ss);
    Logger.log('Setup complete!');
}

function setupFeeSheet() { /* (Your original code) */
    const ss = getSSS();
    let fs = ss.getSheetByName(FEE_SHEET);
    if (!fs) fs = ss.insertSheet(FEE_SHEET);
    const headers = ['RFID UID', 'Roll No', 'Name', 'Class', 'Total Fee (₹)', ...FEE_MONTHS];
    fs.getRange(1, 1, 1, headers.length).setNumberFormat('@STRING@').setValues([headers]).setBackground('#1b5e20').setFontColor('#fff').setFontWeight('bold').setHorizontalAlignment('center');
    fs.setRowHeight(1, 30);
    fs.setFrozenRows(1);
    [130, 80, 160, 100, 120].forEach((w, i) => fs.setColumnWidth(i + 1, w));
    for (let i = 0; i < FEE_MONTHS.length; i++) fs.setColumnWidth(i + 6, 100);
    syncStudentsToFeeSheet();
    Logger.log('Fee sheet ready!');
}

function syncStudentsToFeeSheet() { /* (Your original code) */
    const ss = getSSS();
    const stuSheet = ss.getSheetByName(STUDENT_SHEET);
    const feeSheet = ss.getSheetByName(FEE_SHEET);
    if (!stuSheet || !feeSheet) return;
    const stuData = stuSheet.getDataRange().getValues();
    const feeData = feeSheet.getDataRange().getValues();
    const existingRolls = new Set();
    for (let i = 1; i < feeData.length; i++) {
        if (feeData[i][F.ROLL]) existingRolls.add(feeData[i][F.ROLL].toString());
    }
    let added = 0;
    for (let i = 1; i < stuData.length; i++) {
        const roll = stuData[i][S.ROLL] ? stuData[i][S.ROLL].toString() : '';
        const name = stuData[i][S.NAME] ? stuData[i][S.NAME].toString() : '';
        const cls = stuData[i][S.CLASS] ? stuData[i][S.CLASS].toString() : '';
        if (roll && existingRolls.has(roll)) {
            for (let j = 1; j < feeData.length; j++) {
                if (feeData[j][F.ROLL] && feeData[j][F.ROLL].toString() === roll) {
                    feeSheet.getRange(j + 1, F.NAME + 1).setValue(name);
                    feeSheet.getRange(j + 1, F.CLASS + 1).setValue(cls);
                    break;
                }
            }
            continue;
        }
        if (!roll || roll === '') continue;
        const newRow = [stuData[i][S.UID] || '', roll, stuData[i][S.NAME] || '', stuData[i][S.CLASS] || '', '', ...FEE_MONTHS.map(() => 'PENDING')];
        feeSheet.appendRow(newRow);
        const lastRow = feeSheet.getLastRow();
        feeSheet.getRange(lastRow, F.MONTHS_START + 1, 1, FEE_MONTHS.length).setBackground('#ffcdd2');
        added++;
    }
    Logger.log('Synced ' + added + ' new students to fee sheet');
}

function emailDailyReport() { /* (Your original code) */
    const ss = getSSS();
    const label = Utilities.formatDate(new Date(), TIMEZONE, 'dd-MMM-yyyy');
    const sheet = ss.getSheetByName(label);
    if (!sheet) { Logger.log('No sheet: ' + label); return; }
    const last = sheet.getLastRow();
    let total = 0, inside = 0, left = 0;
    if (last >= 3) {
        sheet.getRange(3, 1, last - 2, 7).getValues().forEach(r => {
            if (!r[0]) return;
            total++;
            r[4] ? left++ : inside++;
        });
    }
    const pdf = exportPDF(ss, sheet);
    const body = `Dear Librarian,\n\nAttached is the library attendance report for ${label}.\n\n── SUMMARY ─────────────────────\n  Total Visited : ${total}\n  Left Library  : ${left}\n  Still Inside  : ${inside}\n────────────────────────────────\n\nRegards,\nLibrary RFID Attendance System v4.0`.trim();
    [REPORT_EMAIL, REPORT_EMAIL2].filter(Boolean).forEach(email => {
        GmailApp.sendEmail(email, 'Library Attendance — ' + label, body, { attachments: [pdf], name: 'Library Attendance System' });
        Logger.log('Sent to: ' + email);
    });
}

function exportPDF(ss, sheet) { /* (Your original code) */
    const url = `https://docs.google.com/spreadsheets/d/${ss.getId()}/export?format=pdf&size=A4&portrait=true&fitw=true&sheetnames=false&printtitle=false&pagenumbers=false&gridlines=true&gid=${sheet.getSheetId()}`;
    const resp = UrlFetchApp.fetch(url, { headers: { Authorization: 'Bearer ' + ScriptApp.getOAuthToken() } });
    const label = Utilities.formatDate(new Date(), TIMEZONE, 'dd-MMM-yyyy');
    return resp.getBlob().setName('Attendance_' + label + '.pdf');
}

function setupDailyTrigger() { /* (Your original code) */
    ScriptApp.getProjectTriggers().filter(t => t.getHandlerFunction() === 'emailDailyReport').forEach(t => ScriptApp.deleteTrigger(t));
    ScriptApp.newTrigger('emailDailyReport').timeBased().everyDays(1).atHour(SEND_TIME_HOUR).nearMinute(0).create();
    Logger.log('Trigger set for ' + SEND_TIME_HOUR + ':00 daily');
}

function createTodaySheet() { Logger.log('Created: ' + getDaySheet(getSSS()).getName()); }
function testEmail() { emailDailyReport(); Logger.log('Test email sent!'); }
function testUploadPhoto() { const testBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwADhQGAWjR9awAAAABJRU5ErkJggg=='; const result = uploadStudentPhoto('1', testBase64, 'image/png'); Logger.log(JSON.stringify(result)); }
function authorizeDrive() { DriveApp.createFolder('RFID_AUTH_TEST'); const folders = DriveApp.getFoldersByName('RFID_AUTH_TEST'); while (folders.hasNext()) folders.next().setTrashed(true); Logger.log('Full Drive access OK!'); }
function addPhotoColumn() { const ss = getSSS(); const stuSheet = ss.getSheetByName(STUDENT_SHEET); stuSheet.getRange(1, 7).setValue('Photo').setBackground('#1a237e').setFontColor('#ffffff').setFontWeight('bold').setHorizontalAlignment('center'); stuSheet.setColumnWidth(7, 200); Logger.log('Photo column added!'); }
function testPhotoUrl() { const ss = getSSS(); const stuSheet = ss.getSheetByName(STUDENT_SHEET); const data = stuSheet.getDataRange().getValues(); for (let i = 1; i < data.length; i++) { if (data[i][S.UID]) { Logger.log('Roll: ' + data[i][S.ROLL] + ' | Photo: ' + (data[i][S.PHOTO] || 'EMPTY')); } } }

function uploadStudentPhoto(roll, base64Data, mimeType) { /* (Your original code) */
    try {
        if (!roll || !base64Data) return { status: 'error', message: 'Roll and photo data required' };
        const folderName = 'Library RFID — Student Photos';
        let folder;
        const folders = DriveApp.getFoldersByName(folderName);
        if (folders.hasNext()) { folder = folders.next(); } else {
            folder = DriveApp.createFolder(folderName);
            folder.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
        }
        const oldFiles = folder.getFilesByName('student_' + roll);
        while (oldFiles.hasNext()) oldFiles.next().setTrashed(true);
        const blob = Utilities.newBlob(Utilities.base64Decode(base64Data), mimeType || 'image/jpeg', 'student_' + roll);
        const file = folder.createFile(blob);
        file.setSharing(DriveApp.Access.ANYONE_WITH_LINK, DriveApp.Permission.VIEW);
        const fileId = file.getId();
        const directUrl = 'https://lh3.googleusercontent.com/d/' + fileId + '=s400';
        const ss = getSSS();
        const stuSheet = ss.getSheetByName(STUDENT_SHEET);
        const data = stuSheet.getDataRange().getValues();
        let updated = false;
        for (let i = 1; i < data.length; i++) {
            if (data[i][S.ROLL] && data[i][S.ROLL].toString() === roll.toString()) {
                stuSheet.getRange(i + 1, S.PHOTO + 1).setValue(directUrl);
                updated = true;
                break;
            }
        }
        if (!updated) return { status: 'error', message: 'Student not found: Roll ' + roll };
        return { status: 'success', url: directUrl, message: 'Photo uploaded for Roll ' + roll };
    } catch (err) { return { status: 'error', message: err.toString() }; }
}
