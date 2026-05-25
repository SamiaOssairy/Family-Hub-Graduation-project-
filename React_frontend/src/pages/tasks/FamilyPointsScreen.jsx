// ═══════════════════════════════════════════════════════════════
// Family Points (Leaderboard) Screen — mirrors family_points_screen.dart
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { Trophy, RefreshCw, Star } from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import Avatar from '../../components/common/Avatar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import EmptyState from '../../components/common/EmptyState';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

const MEDALS = ['🥇', '🥈', '🥉'];

export default function FamilyPointsScreen() {
  const { t } = useTranslation();
  const toast = useToast();
  const [loading, setLoading] = useState(true);
  const [ranking, setRanking] = useState([]);

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const r = await api.getPointsRanking();
      setRanking(r);
    } catch (e) {
      toast(e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { load(); }, [load]);

  const topThree = ranking.slice(0, 3);
  const rest = ranking.slice(3);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar title={t('familyPoints')} actions={<IconBtn icon={RefreshCw} onClick={load} />} />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 500, margin: '0 auto', width: '100%', padding: '20px 16px 32px' }}>
          {ranking.length === 0
            ? <EmptyState icon={Trophy} message="No leaderboard data yet" />
            : (
              <>
                {/* Top 3 podium */}
                {topThree.length > 0 && (
                  <div style={{ marginBottom: 28 }}>
                    <p style={{
                      fontFamily: 'var(--font-family)', fontSize: 13, fontWeight: 700,
                      color: 'var(--color-text-secondary)', letterSpacing: 1,
                      textTransform: 'uppercase', marginBottom: 16, textAlign: 'center',
                    }}>🏆 TOP PERFORMERS</p>

                    {/* Winner card */}
                    {topThree[0] && (
                      <div style={{
                        background: 'linear-gradient(135deg, var(--color-primary), var(--color-primary-light))',
                        borderRadius: 20, padding: '24px 20px',
                        display: 'flex', alignItems: 'center', gap: 16,
                        marginBottom: 10, boxShadow: 'var(--shadow-primary)',
                      }}>
                        <div style={{
                          fontSize: 40, width: 56, height: 56,
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                        }}>🥇</div>
                        <div style={{ flex: 1 }}>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 18, color: '#fff', margin: 0 }}>
                            {topThree[0].member_mail?.split('@')[0] || topThree[0].username || 'Member'}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, color: 'rgba(255,255,255,0.8)', margin: 0 }}>
                            {topThree[0].member_mail}
                          </p>
                        </div>
                        <div style={{ textAlign: 'right' }}>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 900, fontSize: 28, color: '#fff', margin: 0 }}>
                            {topThree[0].total_points || 0}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'rgba(255,255,255,0.8)', margin: 0 }}>pts</p>
                        </div>
                      </div>
                    )}

                    {/* 2nd & 3rd */}
                    <div style={{ display: 'flex', gap: 10 }}>
                      {topThree.slice(1).map((member, i) => (
                        <div key={i} style={{
                          flex: 1,
                          background: 'var(--color-white)', borderRadius: 16,
                          border: '1px solid var(--color-border)',
                          padding: 14, display: 'flex', flexDirection: 'column',
                          alignItems: 'center', gap: 6,
                          boxShadow: 'var(--shadow-card)',
                        }}>
                          <span style={{ fontSize: 26 }}>{MEDALS[i + 1]}</span>
                          <Avatar name={member.member_mail?.split('@')[0] || '?'} size={36} />
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 12, color: 'var(--color-text-primary)', margin: 0, textAlign: 'center' }}>
                            {member.member_mail?.split('@')[0] || 'Member'}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 16, color: 'var(--color-primary)', margin: 0 }}>
                            {member.total_points || 0} pts
                          </p>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {/* Rest of leaderboard */}
                {rest.length > 0 && (
                  <>
                    <p style={{
                      fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 700,
                      color: 'var(--color-text-secondary)', letterSpacing: 1,
                      textTransform: 'uppercase', marginBottom: 10,
                    }}>ALL MEMBERS</p>
                    {rest.map((member, i) => (
                      <div key={i} style={{
                        background: 'var(--color-white)', borderRadius: 14,
                        border: '1px solid var(--color-border)',
                        padding: '12px 14px', marginBottom: 8,
                        display: 'flex', alignItems: 'center', gap: 12,
                        boxShadow: 'var(--shadow-card)',
                      }}>
                        <span style={{
                          fontFamily: 'var(--font-family)', fontWeight: 800, fontSize: 16,
                          color: 'var(--color-text-hint)', width: 24, textAlign: 'center',
                        }}>{i + 4}</span>
                        <Avatar name={member.member_mail?.split('@')[0] || '?'} size={36} />
                        <div style={{ flex: 1 }}>
                          <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 13, color: 'var(--color-text-primary)', margin: 0 }}>
                            {member.member_mail?.split('@')[0] || 'Member'}
                          </p>
                          <p style={{ fontFamily: 'var(--font-family)', fontSize: 10, color: 'var(--color-text-secondary)', margin: 0 }}>
                            {member.member_mail}
                          </p>
                        </div>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                          <Star size={14} color="var(--color-primary)" fill="var(--color-primary)" />
                          <span style={{ fontFamily: 'var(--font-family)', fontWeight: 700, fontSize: 15, color: 'var(--color-primary)' }}>
                            {member.total_points || 0}
                          </span>
                        </div>
                      </div>
                    ))}
                  </>
                )}
              </>
            )
          }
        </div>
      )}
    </div>
  );
}
