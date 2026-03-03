
const express=require('express');
const morgan=require('morgan');
const dotenv=require('dotenv');
const cors=require('cors');
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


const path = require('path');


const app=express();

// Enable CORS for React and Flutter frontends
app.use(cors({
  origin: '*', // Allow all origins during development
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(morgan('dev'));

 

app.use('/api/familyAccounts', familyAccountRouter);
app.use('/api/members', memberRouter);
app.use('/api/memberTypes', memberTypeRouter);
app.use('/api/auth', authRouter);
app.use('/api/tasks', taskRouter);
app.use('/api/task-categories', taskCategoryRouter);
app.use('/api/point-wallet', pointWalletRouter);
app.use('/api/point-history', pointHistoryRouter);
app.use('/api/wishlist', wishlistRouter);
app.use('/api/wishlist-categories', wishlistCategoryRouter);
app.use('/api/redeem', redeemRouter);

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
    const field = Object.keys(err.keyPattern)[0];
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
