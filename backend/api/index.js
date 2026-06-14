const mongoose = require('mongoose');
const app = require('../app');

let isConnected = false;

async function connectDB() {
  if (isConnected) return;
  const dbString = process.env.DB.replace('<db_password>', process.env.DB_PASSWORD);
  await mongoose.connect(dbString);
  isConnected = true;
}

module.exports = async (req, res) => {
  await connectDB();
  return app(req, res);
};
