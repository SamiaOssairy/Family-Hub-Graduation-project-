
const express=require('express');
const morgan=require('morgan');
const dotenv=require('dotenv');
const cors=require('cors');
const rateLimit=require('express-rate-limit');
dotenv.config({path:'./.env'});
 

const familyAccountRouter = require('./routes/familyAccountRoutes');
const memberRouter = require('./routes/memberRoutes');
const memberTypeRouter = require('./routes/memberTypeRoutes');
const authRouter = require('./routes/authRoutes');
const taskRouter = require('./routes/taskRoutes');
const taskCategoryRouter = require('./routes/taskCategoryRoutes');
const pointWalletRouter = require('./routes/pointWalletRoutes');
const pointHistoryRouter = require('./routes/pointHistoryRoutes');
const wishlistRouter = require('./routes/wishlistRoutes');
const wishlistCategoryRouter = require('./routes/wishlistCategoryRoutes');
const redeemRouter = require('./routes/redeemRoutes');
const budgetRouter = require('./routes/BudgetRoutes');
const planningRouter = require('./routes/planningRoutes');

// Food & Tracking module routes
const unitRouter = require('./routes/unitRoutes');
const recipeRouter = require('./routes/recipeRoutes');
const inventoryRouter = require('./routes/inventoryRoutes');
const inventoryCategoryRouter = require('./routes/inventoryCategoryRoutes');
const inventoryAlertRouter = require('./routes/inventoryAlertRoutes');
const receiptRouter = require('./routes/receiptRoutes');
const mealRouter = require('./routes/mealRoutes');
const leftoverRouter = require('./routes/leftoverRoutes');
const mealSuggestionRouter = require('./routes/mealSuggestionRoutes');
const locationRouter = require('./routes/locationRoutes');
const groceryRouter = require('./routes/groceryRoutes');


const path = require('path');


const app=express();

// Enable CORS for React and Flutter frontends.
// Allowed origins: any explicitly configured via CORS_ORIGINS (comma-separated),
// plus localhost (any port, for development) and any *.vercel.app deployment.
// Mobile apps (Flutter) and tools like Postman send no Origin header -> always allowed.
const configuredOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((o) => o.trim())
  .filter(Boolean);

const isAllowedOrigin = (origin) => {
  if (!origin) return true;                       // non-browser clients (Flutter, Postman, curl)
  if (configuredOrigins.includes(origin)) return true;
  if (/^https?:\/\/localhost(:\d+)?$/.test(origin)) return true;
  if (/^https?:\/\/127\.0\.0\.1(:\d+)?$/.test(origin)) return true;
  if (/\.vercel\.app$/.test(origin)) return true; // Vercel deployments
  return false;
};

app.use(cors({
  origin: (origin, callback) => {
    if (isAllowedOrigin(origin)) return callback(null, true);
    return callback(new Error(`Origin ${origin} not allowed by CORS`));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(morgan('dev'));

// Rate limiter for authentication endpoints — protects against brute-force
// password guessing and credential stuffing. Limits each IP to 20 requests
// per 15-minute window on sensitive auth routes.
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,                 // max 100 requests per window per IP
  // ^ generous enough that a room of testers sharing one WiFi/IP won't be blocked,
  //   but still stops automated brute-force (which needs thousands of tries).
  standardHeaders: true,
  legacyHeaders: false,
  message: { message: 'Too many attempts. Please try again in a few minutes.' },
});

 

app.use('/api/familyAccounts', familyAccountRouter);
app.use('/api/members', memberRouter);
app.use('/api/memberTypes', memberTypeRouter);
app.use('/api/auth', authLimiter, authRouter);
app.use('/api/tasks', taskRouter);
app.use('/api/task-categories', taskCategoryRouter);
app.use('/api/point-wallet', pointWalletRouter);
app.use('/api/point-history', pointHistoryRouter);
app.use('/api/wishlist', wishlistRouter);
app.use('/api/wishlist-categories', wishlistCategoryRouter);
app.use('/api/redeem', redeemRouter);
app.use('/api/budget', budgetRouter);
app.use('/api/budgets', budgetRouter);
app.use('/api/planning', planningRouter);

// Food & Tracking module routes
app.use('/api/units', unitRouter);
app.use('/api/recipes', recipeRouter);
app.use('/api/inventory', inventoryRouter);
app.use('/api/inventory-categories', inventoryCategoryRouter);
app.use('/api/inventory-alerts', inventoryAlertRouter);
app.use('/api/receipts', receiptRouter);
app.use('/api/meals', mealRouter);
app.use('/api/leftovers', leftoverRouter);
app.use('/api/meal-suggestions', mealSuggestionRouter);
app.use('/api/location', locationRouter);
app.use('/api/grocery-lists', groceryRouter);

// Global error handler
app.use((err, req, res, next) => {
  console.error('Error:', err);
  
  // Handle Mongoose validation errors
  if (err.name === 'ValidationError') {
    const messages = Object.values(err.errors).map(e => e.message);
    return res.status(400).json({
      message: messages.join('. ')
    });
  }
  
  // Handle duplicate key errors
  if (err.code === 11000) {
    const keyPattern = err.keyPattern || {};

    if (keyPattern.username && keyPattern.family_id) {
      return res.status(400).json({
        message: 'This username already exists in this family. Please choose a different username.'
      });
    }

    if (keyPattern.mail && keyPattern.family_id) {
      return res.status(400).json({
        message: 'This email is already linked to this family.'
      });
    }

    if (keyPattern.member_mail && keyPattern.family_id) {
      return res.status(400).json({
        message: 'This member record already exists for this family.'
      });
    }

    const field = Object.keys(keyPattern)[0] || 'field';
    const fieldName = field === 'mail' ? 'email' : field;
    return res.status(400).json({
      message: `This ${fieldName} is already registered. Please use a different one.`
    });
  }
  
  // Handle custom AppError
  if (err.statusCode) {
    return res.status(err.statusCode).json({
      message: err.message
    });
  }
  
  // Default error
  res.status(500).json({
    message: err.message || 'Something went wrong! Please try again.'
  });
});

module.exports=app;
