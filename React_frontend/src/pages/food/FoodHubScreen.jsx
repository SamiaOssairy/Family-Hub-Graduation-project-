// ═══════════════════════════════════════════════════════════════
// Food Hub Screen — mirrors food_hub_screen.dart exactly
// ═══════════════════════════════════════════════════════════════
import React, { useState, useEffect, useCallback } from 'react';
import { useTranslation } from 'react-i18next';
import { useNavigate } from 'react-router-dom';
import {
  Layers, BookOpen, Archive, CalendarDays,
  ShoppingCart, Lightbulb, Receipt, Bell, AlertTriangle, Clock,
  BellRing, RefreshCw,
} from 'lucide-react';
import AppBar, { IconBtn } from '../../components/common/AppBar';
import LoadingSpinner from '../../components/common/LoadingSpinner';
import { useToast } from '../../components/common/Toast';
import * as api from '../../api/apiService';

function isLowStock(item) {
  const qty = +(item.quantity || 0);
  const thr = +(item.threshold_quantity || 0);
  return thr > 0 && qty <= thr;
}

export default function FoodHubScreen() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const toast = useToast();

  const [loading, setLoading]             = useState(true);
  const [familyTitle, setFamilyTitle]     = useState('My Family');
  const [totalItems, setTotalItems]       = useState(0);
  const [lowStockCount, setLowStockCount] = useState(0);
  const [totalRecipes, setTotalRecipes]   = useState(0);
  const [totalLeftovers, setTotalLeftovers] = useState(0);
  const [expiringLeftovers, setExpiringLeftovers] = useState(0);
  const [unreadAlerts, setUnreadAlerts]   = useState(0);
  const [expiringList, setExpiringList]   = useState([]);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      setFamilyTitle(localStorage.getItem('familyTitle') || 'My Family');

      const [items, recipes, leftovers, expiringData, alertCount] = await Promise.all([
        api.getAllFamilyItems().catch(() => []),
        api.getAllRecipes().catch(() => []),
        api.getAllLeftovers().catch(() => []),
        api.getExpiringLeftovers().catch(() => ({})),
        api.getUnreadAlertCount().catch(() => 0),
      ]);

      const expList = expiringData?.data?.leftovers || [];
      let lowStock = 0;
      for (const item of items) {
        if (isLowStock(item)) lowStock++;
      }

      setTotalItems(items.length);
      setLowStockCount(lowStock);
      setTotalRecipes(recipes.length);
      setTotalLeftovers(leftovers.length);
      setExpiringLeftovers(expList.length);
      setUnreadAlerts(alertCount);
      setExpiringList(expList.slice(0, 4));
    } catch (e) {
      toast('Error loading data: ' + e.message, 'error');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { loadData(); }, [loadData]);

  function daysUntil(dateStr) {
    try {
      const date = new Date(dateStr);
      return Math.floor((date - new Date()) / 864e5);
    } catch { return 999; }
  }

  const STAT_CARDS = [
    {
      label: t('inventory'), value: `${totalItems}`, icon: Layers,
      color: 'var(--color-primary)',
      badge: lowStockCount > 0 ? `${lowStockCount} ${t('lowStock')}` : null,
      badgeColor: '#E53935', route: '/inventory',
    },
    {
      label: t('recipes'), value: `${totalRecipes}`, icon: BookOpen,
      color: '#FB8C00', route: '/recipes',
    },
    {
      label: t('leftovers'), value: `${totalLeftovers}`, icon: Archive,
      color: 'var(--color-primary-light)',
      badge: expiringLeftovers > 0 ? `${expiringLeftovers} ${t('exp')}` : null,
      badgeColor: '#FB8C00', route: '/leftovers',
    },
  ];

  const QUICK_ACTIONS = [
    { title: t('inventory'),  icon: Layers,    color: 'var(--color-primary)', route: '/inventory' },
    { title: 'Categories',    icon: Layers,    color: '#6D4C41',              route: '/inventory-categories' },
    { title: t('recipes'),    icon: BookOpen,  color: '#FB8C00',              route: '/recipes' },
    { title: t('mealPlan'),   icon: CalendarDays, color: 'var(--color-primary-light)', route: '/meals' },
    { title: t('groceries'),  icon: ShoppingCart, color: '#00BCD4',           route: '/groceries' },
    { title: t('leftovers'),  icon: Archive,   color: '#7B1FA2',              route: '/leftovers' },
    { title: t('suggestions'), icon: Lightbulb, color: '#E91E63',             route: '/meal-suggestions' },
    { title: t('receipts'),   icon: Receipt,   color: '#607D8B',              route: '/receipts' },
    { title: t('alerts'),     icon: BellRing,  color: '#E53935',              route: '/inventory-alerts' },
  ];

  return (
    <div style={{ display: 'flex', flexDirection: 'column', minHeight: '100vh', background: 'var(--color-background)' }}>
      <AppBar
        title={t('foodHub')}
        actions={
          <>
            <div style={{ position: 'relative' }}>
              <IconBtn icon={Bell} onClick={() => navigate('/inventory-alerts')} />
              {unreadAlerts > 0 && (
                <span style={{
                  position: 'absolute', top: 8, right: 8,
                  width: 8, height: 8, borderRadius: '50%',
                  background: '#E53935',
                  border: '1.5px solid var(--color-background)',
                }} />
              )}
            </div>
            <IconBtn icon={RefreshCw} onClick={loadData} />
          </>
        }
      />

      {loading ? <LoadingSpinner /> : (
        <div style={{ flex: 1, maxWidth: 700, margin: '0 auto', width: '100%' }}>
          <div style={{ padding: '16px 20px 80px', overflowY: 'auto' }}>
            {/* Stat cards */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10, marginBottom: 24 }}>
              {STAT_CARDS.map((s, i) => (
                <div key={i} onClick={() => navigate(s.route)} style={{
                  background: 'var(--color-white)', borderRadius: 16, padding: 14,
                  boxShadow: 'var(--shadow-card)', cursor: 'pointer',
                  transition: 'transform 0.15s',
                }}>
                  <div style={{
                    width: 38, height: 38, borderRadius: 10,
                    background: s.color + '1A',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                    marginBottom: 10,
                  }}>
                    <s.icon size={22} color={s.color} />
                  </div>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, color: 'var(--color-text-secondary)', margin: 0 }}>{s.label}</p>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 20, fontWeight: 800, color: 'var(--color-text-primary)', margin: '2px 0 0' }}>{s.value}</p>
                  {s.badge && (
                    <p style={{ fontFamily: 'var(--font-family)', fontSize: 11, fontWeight: 600, color: s.badgeColor, margin: '2px 0 0' }}>
                      {s.badge}
                    </p>
                  )}
                </div>
              ))}
            </div>

            {/* Quick Actions */}
            <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: 'var(--color-text-primary)', marginBottom: 14 }}>
              {t('quickActions')}
            </p>
            <div style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(3, 1fr)',
              gap: 12, marginBottom: 24,
            }}>
              {QUICK_ACTIONS.map((a, i) => (
                <div key={i} onClick={() => navigate(a.route)} style={{
                  background: 'var(--color-white)', borderRadius: 16,
                  boxShadow: 'var(--shadow-card)',
                  padding: '16px 8px', cursor: 'pointer',
                  display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8,
                  transition: 'transform 0.15s',
                }}>
                  <div style={{
                    width: 52, height: 52, borderRadius: 14,
                    background: a.color + '1A',
                    display: 'flex', alignItems: 'center', justifyContent: 'center',
                  }}>
                    <a.icon size={28} color={a.color} />
                  </div>
                  <p style={{
                    fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                    color: 'var(--color-text-primary)', textAlign: 'center', margin: 0,
                  }}>{a.title}</p>
                </div>
              ))}
            </div>

            {/* Expiring soon */}
            {expiringList.length > 0 && (
              <>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <p style={{ fontFamily: 'var(--font-family)', fontSize: 18, fontWeight: 700, color: 'var(--color-text-primary)', margin: 0 }}>
                    {t('expiringSoon')}
                  </p>
                  <button onClick={() => navigate('/leftovers')} style={{
                    background: 'none', border: 'none',
                    fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 600,
                    color: 'var(--color-primary)', cursor: 'pointer',
                  }}>{t('viewAll')}</button>
                </div>
                {expiringList.map((lft, i) => {
                  const days = daysUntil(lft.expiry_date);
                  const isExpired = days < 0;
                  const alertColor = isExpired ? '#E53935' : '#FB8C00';
                  return (
                    <div key={i} style={{
                      background: 'var(--color-white)', borderRadius: 12, padding: 14,
                      marginBottom: 8,
                      border: `1px solid ${alertColor}4D`,
                      display: 'flex', gap: 12, alignItems: 'center',
                    }}>
                      <div style={{
                        width: 36, height: 36, borderRadius: 10,
                        background: alertColor + '1A',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>
                        {isExpired ? <AlertTriangle size={20} color={alertColor} /> : <Clock size={20} color={alertColor} />}
                      </div>
                      <div>
                        <p style={{ fontFamily: 'var(--font-family)', fontWeight: 600, fontSize: 14, color: 'var(--color-text-primary)', margin: 0 }}>
                          {lft.item_name || lft.name || 'Unknown'}
                        </p>
                        <p style={{ fontFamily: 'var(--font-family)', fontSize: 12, fontWeight: 500, color: alertColor, margin: '2px 0 0' }}>
                          {isExpired
                            ? `Expired ${Math.abs(days)} day${Math.abs(days) !== 1 ? 's' : ''} ago`
                            : days === 0 ? 'Expires today!'
                            : `Expires in ${days} day${days !== 1 ? 's' : ''}`
                          }
                        </p>
                      </div>
                    </div>
                  );
                })}
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
