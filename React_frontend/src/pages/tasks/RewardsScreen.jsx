// ═══════════════════════════════════════════════════════════════
// Rewards Screen — mirrors rewards_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Star, TrendingUp, RefreshCw } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const REASON_EMOJI = {
  task_completion: '✅',
  penalty:         '⚠️',
  redeem:          '🎁',
  bonus:           '🎉',
  adjustment:      '📊',
  manual_grant:    '💝',
  conversion:      '🔄',
};

export default function RewardsScreen() {
  const { t } = useTranslation();
  const toast = useToast();

  const [loading, setLoading]   = useState(true);
  const [wallet, setWallet]     = useState(null);
  const [history, setHistory]   = useState([]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const [w, h] = await Promise.all([
        api.getMyWallet(),
        api.getMyPointHistory(),
      ]);
      setWallet(w);
      setHistory(h);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const formatDate = (dateStr) => {
    try {
      return new Date(dateStr).toLocaleDateString('en-EG', {
        day: '2-digit', month: 'short', year: 'numeric',
      });
    } catch { return dateStr; }
  };

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title={t('myRewards')} actions={<IconBtn icon={RefreshCw} onClick={load} />} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 600, margin: '0 auto', width: '100%', padding: '16px 16px 32px' }}>
          {/* Points card */}
          <div style={{
            background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
            borderRadius: 20, padding: 24, marginBottom: 24,
            boxShadow: 'var(--shadow-primary)',
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          }}>
            <div>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'rgba(255,255,255,0.8)', margin: 0 }}>
                {t('totalPoints')}
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 42, fontWeight: 800, color: '#fff', margin: '4px 0 0' }}>
                {wallet?.total_points || 0}
              </p>
              <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'rgba(255,255,255,0.8)', margin: 0 }}>
                pts
              </p>
            </div>
            <div style={{
              width: 72, height: 72, borderRadius: '50%',
              background: 'rgba(255,255,255,0.2)',
              display: 'flex', alignItems: 'center', justifyContent: 'center',
            }}>
              <Star size={36} color="#fff" fill="#fff" />
            </div>
          </div>

          {/* History */}
          <div style={{ marginBottom: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 15, fontWeight: 700, color: 'var(--color-text-primary)', margin: 0 }}>
              {t('pointsHistory')}
            </p>
            <span style={{
              fontFamily: 'var(--font-family)', fontSize: 11, color: 'var(--color-text-secondary)',
              background: 'var(--color-primary-surface)', borderRadius: 10, padding: '3px 10px',
              border: '1px solid var(--color-border)',
            }}>
              {history.length} records
            </span>
          </div>

          {history.length === 0
            ? <EmptyState icon={TrendingUp} message={t('noHistory')} />
            : history.map((item, i) => {
              const isPositive = item.points_amount > 0;
              const emoji = REASON_EMOJI[item.reason_type] || '📌';
              return (
                <div key={i} style={{
                  background: 'var(--color-white)',
                  borderRadius: 14, padding: 14,
                  marginBottom: 8,
                  border: `1px solid ${isPositive ? 'var(--color-border-light)' : '#FFCDD2'}`,
                  display: 'flex', alignItems: 'center', gap: 12,
                  boxShadow: 'var(--shadow-card)',
                }}>
                  <div style={{
                    width: 40, height: 40, borderRadius: '50%',
                    background: isPositive ? 'var(--color-primary-surface)' : '#FFEBEE',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    fontSize: 20, flexShrink: 0,
                  }}>{emoji}</div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                      {item.description || item.reason_type?.replace(/_/g, ' ')}
                    </p>
                    <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: '2px 0 0' }}>
                      {formatDate(item.createdAt)}
                    </p>
                  </div>
                  <div style={{ textAlign: 'right', flexShrink: 0 }}>
                    <p style={{
                      fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 16,
                      color: isPositive ? 'var(--color-primary)' : '#E53935',
                      margin: 0,
                    }}>
                      {isPositive ? '+' : ''}{item.points_amount}
                    </p>
                    <p style={{ fontFamily: 'var(--font-family)', fontSize: 9, color: 'var(--color-text-hint)', margin: 0 }}>
                      pts
                    </p>
                  </div>
                </div>
              );
            })
          }
        </div>
      )}
    </div>
  );
}
