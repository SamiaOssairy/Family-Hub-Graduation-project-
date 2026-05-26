import axios from 'axios';

const API_BASE_URL = process.env.REACT_APP_API_URL || 'http://localhost:8000/api';

const api = axios.create({
  baseURL: API_BASE_URL,
  headers: { 'Content-Type': 'application/json' },
});

// Attach JWT token to every request automatically
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) config.headers.Authorization = `Bearer ${token}`;
  return config;
});

// ─── Auth ────────────────────────────────────────────────────────────────────
export const authAPI = {
  // Step 1: get all families linked to an email
  getFamiliesByEmail: async (mail) => {
    const res = await api.get(`/auth/families?mail=${encodeURIComponent(mail)}`);
    // backend returns { message, data: { mail, families: [...] } }
    return res.data.data?.families || res.data.families || [];
  },

  // Step 2: login with email + password + chosen family_id
  login: async ({ mail, password, family_id }) => {
    const res = await api.post('/auth/login', { mail, password, family_id });
    return res.data; // { token, data: { member, family } }
  },

  // Sign up — create new family + parent member
  signup: async ({ familyTitle, mail, username, password, birthDate }) => {
    const res = await api.post('/auth/signup', {
      Title: familyTitle,
      mail,
      username,
      password,
      birth_date: birthDate,
    });
    return res.data;
  },
};

// ─── Members ─────────────────────────────────────────────────────────────────
export const memberAPI = {
  getAll: async () => {
    const res = await api.get('/members');
    return res.data;
  },
  create: async (data) => {
    const res = await api.post('/members', data);
    return res.data;
  },
  remove: async (memberId) => {
    const res = await api.delete(`/members/${memberId}`);
    return res.data;
  },
};

// ─── Member Types ─────────────────────────────────────────────────────────────
export const memberTypeAPI = {
  getAll: async () => {
    const res = await api.get('/memberTypes');
    return res.data;
  },
};

export default api;
