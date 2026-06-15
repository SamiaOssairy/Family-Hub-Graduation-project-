// ═══════════════════════════════════════════════════════════════════════════════
// PlanningChatScreen — React equivalent of flutter_app/lib/pages/planning_chat_screen.dart
// AI planning assistant powered by Gemini via /api/planning/chat
// ═══════════════════════════════════════════════════════════════════════════════
import React, { useState, useEffect, useRef } from 'react';
import { useTheme } from '../context/ThemeContext';
import BottomNavBar from '../components/common/BottomNavBar';
import api from '../api/apiService';
import './PlanningChatScreen.css';

// ── Suggestion list (matches Flutter's _suggestions array exactly) ────────────
const SUGGESTIONS_EN = [
  'What was our average budget for the last 3 months?',
  'Who was the best child in the past 2 weeks?',
  'What do you suggest to save money next month?',
  'Suggest meals for today based on what we have.',
  'Which category did we overspend on?',
  'How many tasks were completed this week?',
];
const SUGGESTIONS_AR = [
  'ما متوسط ميزانيتنا في آخر 3 أشهر؟',
  'من كان أفضل طفل في الأسبوعين الماضيين؟',
  'ماذا تقترح لتوفير المال الشهر القادم؟',
  'اقترح وجبات لليوم بناءً على ما لدينا.',
  'ما الفئة التي تجاوزنا ميزانيتها؟',
  'كم مهمة أُنجزت هذا الأسبوع؟',
];

// ─────────────────────────────────────────────────────────────────────────────
export default function PlanningChatScreen() {
  const { language } = useTheme();
  const t = (en, ar) => language === 'ar' ? ar : en;

  const [messages,    setMessages]    = useState([]);
  const [input,       setInput]       = useState('');
  const [loading,     setLoading]     = useState(false);
  const [histLoading, setHistLoading] = useState(true);
  const [showConfirm, setShowConfirm] = useState(false);   // clear history dialog

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

  // ── Clear history — shows confirmation dialog first (Flutter parity) ───────
  function promptClearHistory() {
    setShowConfirm(true);
  }

  async function confirmClearHistory() {
    setShowConfirm(false);
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
      const reply = res.data?.data?.response || t('No response', 'لا يوجد رد');
      setMessages(prev => [...prev, { role: 'assistant', content: reply }]);
    } catch (e) {
      const errMsg = e?.response?.data?.message
        || t('Sorry, something went wrong. Please try again.', 'عذراً، حدث خطأ. يرجى المحاولة مجدداً.');
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

      {/* ── Confirm dialog ────────────────────────────────────────────────── */}
      {showConfirm && (
        <div className="pc-dialog-overlay" onClick={() => setShowConfirm(false)}>
          <div className="pc-dialog" onClick={e => e.stopPropagation()}>
            <h3 className="pc-dialog-title">{t('Clear History', 'مسح السجل')}</h3>
            <p className="pc-dialog-body">
              {t(
                'Are you sure you want to clear the entire chat history?',
                'هل أنت متأكد من مسح سجل المحادثة بالكامل؟'
              )}
            </p>
            <div className="pc-dialog-actions">
              <button className="pc-dialog-cancel" onClick={() => setShowConfirm(false)}>
                {t('Cancel', 'إلغاء')}
              </button>
              <button className="pc-dialog-clear" onClick={confirmClearHistory}>
                {t('Clear', 'مسح')}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ── Header ────────────────────────────────────────────────────────── */}
      <div className="pc-header">
        <div className="pc-header-avatar">🤖</div>
        <div className="pc-header-text">
          <span className="pc-header-title">{t('Family AI Assistant', 'مساعد العائلة الذكي')}</span>
          <span className="pc-header-sub">{t('Powered by Gemini', 'مدعوم بـ Gemini')}</span>
        </div>
        {messages.length > 0 && (
          <button
            className="pc-clear-btn"
            title={t('Clear history', 'مسح السجل')}
            onClick={promptClearHistory}
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
            <h3 className="pc-empty-title">
              {t('Ask me anything about your family!', 'اسألني أي شيء عن عائلتك!')}
            </h3>
            <p className="pc-empty-sub">
              {t(
                'Budget, tasks, points, suggestions and more.',
                'الميزانية، المهام، النقاط، والاقتراحات وأكثر.'
              )}
            </p>
            <p className="pc-empty-try">{t('Try asking:', 'جرب أن تسأل:')}</p>
            {/* Full-width suggestion list tiles (matches Flutter's _buildSuggestionChip) */}
            <div className="pc-suggestion-list">
              {suggestions.map((s, i) => (
                <button
                  key={i}
                  className="pc-suggestion-tile"
                  onClick={() => sendMessage(s)}
                >
                  <span className="pc-suggestion-icon">💬</span>
                  <span className="pc-suggestion-text">{s}</span>
                  <span className="pc-suggestion-arrow">›</span>
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
                <div className={`pc-bubble${msg.role === 'user' ? ' user' : ' ai'}`}>
                  {/* AI Assistant label — matches Flutter's _buildMessageBubble */}
                  {msg.role !== 'user' && (
                    <div className="pc-ai-label">
                      <span className="pc-ai-label-icon">🤖</span>
                      <span className="pc-ai-label-text">{t('AI Assistant', 'المساعد الذكي')}</span>
                    </div>
                  )}
                  <span className="pc-bubble-text">{msg.content}</span>
                </div>
              </div>
            ))}

            {/* Typing indicator */}
            {loading && (
              <div className="pc-bubble-row ai">
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
          placeholder={t('Ask about budget, tasks, points…', 'اسأل عن الميزانية، المهام، النقاط…')}
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
          {loading ? '⏳' : '➤'}
        </button>
      </div>

      <BottomNavBar activeIndex={2} />
    </div>
  );
}
