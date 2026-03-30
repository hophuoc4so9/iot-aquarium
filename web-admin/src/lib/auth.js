const AUTH_STORAGE_KEY = "aq-admin-auth";
const API_BASE = (import.meta.env.VITE_API_BASE ?? "http://localhost:8080").replace(/\/+$/, "");

let fetchInterceptorInstalled = false;

function encodeBase64(value) {
  const bytes = new TextEncoder().encode(value);
  let binary = "";
  bytes.forEach((byte) => {
    binary += String.fromCharCode(byte);
  });
  return btoa(binary);
}

function toBasicAuthHeader(username, password) {
  return `Basic ${encodeBase64(`${username}:${password}`)}`;
}

function normalizeSession(session) {
  if (!session || typeof session !== "object") return null;
  if (!session.authorization || !session.user) return null;
  return {
    authorization: session.authorization,
    user: session.user,
    loggedInAt: session.loggedInAt ?? new Date().toISOString(),
  };
}

export function getStoredAuthSession() {
  try {
    const raw = localStorage.getItem(AUTH_STORAGE_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw);
    return normalizeSession(parsed);
  } catch {
    return null;
  }
}

function saveAuthSession(session) {
  localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(session));
}

export function clearAuthSession() {
  localStorage.removeItem(AUTH_STORAGE_KEY);
}

export async function loginAdmin(username, password) {
  const authorization = toBasicAuthHeader(username, password);

  const res = await fetch(`${API_BASE}/api/auth/me`, {
    headers: { Authorization: authorization },
  });

  if (!res.ok) {
    let errorText = "Đăng nhập thất bại. Vui lòng kiểm tra tài khoản hoặc mật khẩu.";
    try {
      const data = await res.json();
      if (data?.error) errorText = data.error;
    } catch {
      // Keep default error message when server does not return JSON.
    }
    throw new Error(errorText);
  }

  const user = await res.json();
  const session = {
    authorization,
    user,
    loggedInAt: new Date().toISOString(),
  };
  saveAuthSession(session);
  return session;
}

function shouldAttachAuth(url) {
  try {
    const requestUrl = new URL(url, window.location.origin);
    const apiUrl = new URL(API_BASE, window.location.origin);
    return requestUrl.origin === apiUrl.origin && requestUrl.pathname.startsWith("/api/");
  } catch {
    return false;
  }
}

export function installAuthFetchInterceptor() {
  if (fetchInterceptorInstalled) return;

  const nativeFetch = window.fetch.bind(window);
  window.fetch = async (input, init) => {
    let request = new Request(input, init);

    if (shouldAttachAuth(request.url) && !request.headers.has("Authorization")) {
      const session = getStoredAuthSession();
      if (session?.authorization) {
        const headers = new Headers(request.headers);
        headers.set("Authorization", session.authorization);
        request = new Request(request, { headers });
      }
    }

    return nativeFetch(request);
  };

  fetchInterceptorInstalled = true;
}