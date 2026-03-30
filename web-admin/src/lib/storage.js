const PONDS_KEY = "aq-ponds";
const USERS_KEY = "aq-users";
const DIAGNOSIS_LOG_KEY = "aq-diagnosis-log";

export function getPonds() {
  try {
    const raw = localStorage.getItem(PONDS_KEY);
    if (!raw) return [];
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function savePonds(ponds) {
  localStorage.setItem(PONDS_KEY, JSON.stringify(ponds));
}

export function getUsers() {
  try {
    const raw = localStorage.getItem(USERS_KEY);
    if (!raw) return getDefaultUsers();
    return JSON.parse(raw);
  } catch {
    return getDefaultUsers();
  }
}

function getDefaultUsers() {
  return [
    { id: "1", username: "admin", fullName: "Quản trị viên", role: "ADMIN", email: "admin@aquarium.local" },
    { id: "2", username: "farmer1", fullName: "Người nuôi 1", role: "FARMER", email: "farmer1@local" },
  ];
}

export function saveUsers(users) {
  localStorage.setItem(USERS_KEY, JSON.stringify(users));
}

export function getDiagnosisLog() {
  try {
    const raw = localStorage.getItem(DIAGNOSIS_LOG_KEY);
    if (!raw) return [];
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export function appendDiagnosisLog(entry) {
  const log = getDiagnosisLog();
  log.unshift({ id: Date.now().toString(), ...entry, createdAt: new Date().toISOString() });
  localStorage.setItem(DIAGNOSIS_LOG_KEY, JSON.stringify(log.slice(0, 200)));
}
