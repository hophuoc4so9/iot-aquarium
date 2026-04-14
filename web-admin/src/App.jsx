import React, { useState, useEffect } from "react";
import AdminLayout from "./layout/AdminLayout";
import Dashboard from "./pages/dashboard/Dashboard";
import FishSpeciesManager from "./pages/thresholds/FishSpeciesManager";
import AiReportsPage from "./pages/ai/AiReportsPage";
import PondsManager from "./pages/ponds/PondsManager";
import HistoryChartsPage from "./pages/monitoring/HistoryChartsPage";
import ThresholdConfigPage from "./pages/thresholds/ThresholdConfigPage";
import DiagnosisLog from "./pages/ai/DiagnosisLog";
import UserManagement from "./pages/users/UserManagement";
import ChatHistoryPage from "./pages/ai/ChatHistoryPage";
import LoginPage from "./pages/auth/LoginPage";
import {
  clearAuthSession,
  getStoredAuthSession,
  installAuthFetchInterceptor,
  loginAdmin,
} from "./lib/auth";

/**
 * Smart Aquarium - Web Admin
 * Trang quản trị toàn hệ thống: ao nuôi, thiết bị IoT, cảnh báo, AI & báo cáo, người dùng.
 */

export default function App() {
  installAuthFetchInterceptor();

  const getInitialTab = () => {
    const hash = window.location.hash.replace("#/", "");
    return hash || "dashboard";
  };

  const [activeTab, setActiveTab] = useState(getInitialTab);
  const [authSession, setAuthSession] = useState(() => getStoredAuthSession());
  const [isLoginLoading, setIsLoginLoading] = useState(false);

  useEffect(() => {
    const onHashChange = () => {
      const hash = window.location.hash.replace("#/", "");
      if (hash) {
        setActiveTab(hash);
      }
    };
    window.addEventListener("hashchange", onHashChange);
    return () => window.removeEventListener("hashchange", onHashChange);
  }, []);

  useEffect(() => {
    if (!authSession) {
      if (window.location.hash !== "#/login") {
        window.location.hash = "#/login";
      }
      return;
    }

    if (!window.location.hash || window.location.hash === "#/login") {
      window.location.hash = "#/dashboard";
    }
  }, [authSession]);

  const renderContent = () => {
    switch (activeTab) {
      case "dashboard":
        return <Dashboard />;
      case "ponds":
        return <PondsManager />;
      case "users":
        return <UserManagement />;
      case "charts":
        return <HistoryChartsPage />;
      case "threshold-config":
        return <ThresholdConfigPage />;
      case "thresholds":
        return <FishSpeciesManager />;
      case "ai":
      case "federated-learning":
        return <AiReportsPage />;
      case "diagnosis-log":
        return <DiagnosisLog />;
      case "chat-history":
        return <ChatHistoryPage />;
      default:
        return <Dashboard />;
    }
  };

  const handleTabChange = (key) => {
    setActiveTab(key);
    window.location.hash = `#/${key}`;
  };

  const handleLogin = async (username, password) => {
    setIsLoginLoading(true);
    try {
      const session = await loginAdmin(username, password);
      setAuthSession(session);
    } finally {
      setIsLoginLoading(false);
    }
  };

  const handleLogout = () => {
    clearAuthSession();
    setAuthSession(null);
  };

  if (!authSession) {
    return <LoginPage onLogin={handleLogin} loading={isLoginLoading} />;
  }

  return (
    <AdminLayout
      activeTab={activeTab}
      onTabChange={handleTabChange}
      onLogout={handleLogout}
      currentUser={authSession.user}
    >
      {renderContent()}
    </AdminLayout>
  );
}
