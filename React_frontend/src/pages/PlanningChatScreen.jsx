// ═══════════════════════════════════════════════════════════════════════════════
// PlanningChatScreen — React equivalent of flutter_app/lib/pages/planning_chat_screen.dart
// AI planning assistant powered by Gemini via /api/planning/chat
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect, useRef } from 'react';
import { useTheme } from '../context/ThemeContext';
import BottomNavBar from '../components/common/BottomNavBar';
import api from '../api/apiService';
import './PlanningChatScreen.css';

// ── Suggestion chips (matches Flutter's suggestion chips) ─────────────────────
const SUGGESTIONS_EN = [
  'What is our budget overview?',
  'Who earned the most points this week?',
  'What can we cook with our inventory?',
  'Show our family task summary',
  'How much have we saved for events?',
  'Suggest meals for today',
];
const SUGGESTIONS_AR = [
  'ما هو ملخص ميزانيتنا؟',
  'من حصل على أكثر النقاط هذا الأسبوع؟',
  'ماذا يمكننا طهيه من مخزوننا؟',
  'أظهر ملخص مهام العائلة',
  'كم وفّرنا للأحداث؟',
  'اقترح وجبات لليوم',
];

// ─────────────────────────────────────────────────────────────────────────────
export default function PlanningChatScreen() {
  const { language } = useTheme();
  const t = (en, ar) => language === 'ar' ? ar : en;

  const [messages,    setMessages]    = useState([]);
  const [input,       setInput]       = useState('');
  const [loading,     setLoading]     = useState(false);      // sending
  const [histLoading, setHistLoading] = useState(true);      // initial load

  const bottomRef = useRef(null);
  const inputRef  = useRef(null);

  const suggestions = language === 'ar' ? SUGGESTIONS_AR : SUGGESTIONS_EN;

  // ── Load history on mount ──────────────────────────────────────────────────
  useEffect(() => {
    loadHistory();
  }, []);

  // ── Auto-scroll to bottom ──────────────────────────────────────────────────
  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, loading]);

  async function loadHistory() {
    setHistLoading(true);
    try {
      const res = await api.get('/planning/history');
      const history = res.data?.data?.messages || [];
      setMessages(history.map(m => ({ role: m.role, content: m.content })));
    } catch {
      // Silent — empty state shown
    } finally {
      setHistLoading(false);
    }
  }

  async function clearHistory() {
    try {
      await api.delete('/planning/history');
      setMessages([]);
    } catch { /* silent */ }
  }

  // ── Send message ───────────────────────────────────────────────────────────
  async function sendMessage(text) {
    const msg = (text || input).trim();
    if (!msg || loading) return;
    setInput('');
    setMessages(prev => [...prev, { role: 'user', content: msg }]);
    setLoading(true);
    try {
      const res = await api.post('/planning/chat', { message: msg });
      const reply = res.data?.data?.reply || t('No response', 'لا يوجد رد');
      setMessages(prev => [...prev, { role: 'assistant', content: reply }]);
    } catch (e) {
      const errMsg = e?.response?.data?.message || t('Failed to get response', 'فشل الحصول على رد');
      setMessages(prev => [...prev, { role: 'assistant', content: `⚠️ ${errMsg}` }]);
    } finally {
      setLoading(false);
    }
  }

  function handleKeyDown(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  return (
    <div className="pc-root">

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="pc-header">
        <div className="pc-header-avatar">🤖</div>
        <div className="pc-header-text">
          <span className="pc-header-title">{t('Family AI Assistant', 'المساعد الذكي للعائلة')}</span>
          <span className="pc-header-sub">{t('Powered by Gemini AI', 'مدعوم بتقنية Gemini AI')}</span>
        </div>
        {messages.length > 0 && (
          <button
            className="pc-clear-btn"
            title={t('Clear history', 'مسح المحادثة')}
            onClick={clearHistory}
          >
            🗑️
          </button>
        )}
      </div>

      {/* ── Messages Area ─────────────────────────────────────────────────── */}
      <div className="pc-messages-area">
        {histLoading ? (
          <div className="pc-center">
            <div className="pc-spinner" />
          </div>
        ) : messages.length === 0 ? (
          <div className="pc-empty">
            <div className="pc-empty-icon">🤖</div>
            <h3 className="pc-empty-title">{t('Family AI Assistant', 'المساعد الذكي للعائلة')}</h3>
            <p className="pc-empty-sub">
              {t(
                'Ask me anything about your family — budgets, tasks, meals, events, and more!',
                'اسألني أي شيء عن عائلتك — الميزانيات والمهام والوجبات والأحداث وأكثر!'
              )}
            </p>
            <div className="pc-chips">
              {suggestions.map((s, i) => (
                <button
                  key={i}
                  className="pc-chip"
                  onClick={() => sendMessage(s)}
                >
                  {s}
                </button>
              ))}
            </div>
          </div>
        ) : (
          <div className="pc-msg-list">
            {messages.map((msg, i) => (
              <div
                key={i}
                className={`pc-bubble-row${msg.role === 'user' ? ' user' : ' ai'}`}
              >
                {msg.role !== 'user' && (
                  <div className="pc-ai-avatar">🤖</div>
                )}
                <div className={`pc-bubble${msg.role === 'user' ? ' user' : ' ai'}`}>
                  <span className="pc-bubble-text">{msg.content}</span>
                </div>
              </div>
            ))}

            {/* Typing indicator */}
            {loading && (
              <div className="pc-bubble-row ai">
                <div className="pc-ai-avatar">🤖</div>
                <div className="pc-bubble ai pc-typing">
                  <span className="pc-dot" />
                  <span className="pc-dot" />
                  <span className="pc-dot" />
                </div>
              </div>
            )}
            <div ref={bottomRef} />
          </div>
        )}
      </div>

      {/* ── Input Bar ─────────────────────────────────────────────────────── */}
      <div className="pc-input-bar">
        <textarea
          ref={inputRef}
          className="pc-input"
          placeholder={t('Ask your family assistant...', 'اسأل مساعد العائلة...')}
          value={input}
          onChange={e => setInput(e.target.value)}
          onKeyDown={handleKeyDown}
          rows={1}
          disabled={loading}
        />
        <button
          className={`pc-send-btn${(!input.trim() || loading) ? ' disabled' : ''}`}
          onClick={() => sendMessage()}
          disabled={!input.trim() || loading}
        >
          ➤
        </button>
      </div>

      <BottomNavBar activeIndex={2} />
    </div>
  );
}
