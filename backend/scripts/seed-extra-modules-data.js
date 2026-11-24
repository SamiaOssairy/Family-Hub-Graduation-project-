const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

const FamilyAccount = require('../models/FamilyAccountModel');
const Member = require('../models/MemberModel');
const Wishlist = require('../models/wishlistModel');
const WishlistCategory = require('../models/wishlist_categoryModel');
const WishlistItem = require('../models/wishlist_itemModel');
const Redeem = require('../models/redeemModel');
const GroceryList = require('../models/groceryListModel');
const GroceryItem = require('../models/groceryItemModel');
const Receipt = require('../models/receiptModel');
const LocationShare = require('../models/locationShareModel');
const LocationPermission = require('../models/locationPermissionModel');
const LocationHistory = require('../models/locationHistoryModel');
const LocationAlert = require('../models/locationAlertModel');
const PlanningConversation = require('../models/planningConversationModel');
const MealSuggestion = require('../models/mealSuggestionModel');
const Recipe = require('../models/recipeModel');
const InventoryAlert = require('../models/inventoryAlertModel');
const InventoryItem = require('../models/inventoryItemModel');

dotenv.config({ path: path.join(__dirname, '../.env') });

const FAMILY_EMAIL = 'habiba1278@gmail.com';

const daysAgo = (n) => {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d;
};

async function upsertOne(Model, query, data, label) {
  let doc = await Model.findOne(query);
  if (!doc) {
    doc = await Model.create(data);
    console.log(`  + Created ${label}`);
  } else {
    console.log(`  ~ Exists ${label}`);
  }
  return doc;
}

async function run() {
  const dbStr = process.env.DB.replace('<db_password>', process.env.DB_PASSWORD);
  await mongoose.connect(dbStr);
  console.log('Connected to DB');

  const family = await FamilyAccount.findOne({ mail: FAMILY_EMAIL });
  if (!family) {
    throw new Error(`Family not found for ${FAMILY_EMAIL}`);
  }

  const parent = await Member.findOne({ mail: FAMILY_EMAIL, family_id: family._id });
  const ahmed = await Member.findOne({ mail: 'ahmed.family@gmail.com', family_id: family._id });
  const ziad = await Member.findOne({ mail: 'ziad.family@gmail.com', family_id: family._id });
  const noor = await Member.findOne({ mail: 'noor.family@gmail.com', family_id: family._id });

  if (!parent || !ahmed || !ziad || !noor) {
    throw new Error('Required members are missing. Run seed-ai-test-data.js first.');
  }

  console.log(`Family: ${family.Title}`);

  // Wishlist + Wishlist categories + Wishlist items
  console.log('\n=== Wishlist Data ===');
  const catToys = await upsertOne(
    WishlistCategory,
    { title: 'Toys', family_id: family._id },
    { title: 'Toys', description: 'Kids toys and games', family_id: family._id },
    'WishlistCategory: Toys'
  );
  const catLearning = await upsertOne(
    WishlistCategory,
    { title: 'Learning', family_id: family._id },
    { title: 'Learning', description: 'Educational goals', family_id: family._id },
    'WishlistCategory: Learning'
  );

  const wishlistAhmed = await upsertOne(
    Wishlist,
    { member_mail: ahmed.mail, family_id: family._id },
    { member_mail: ahmed.mail, family_id: family._id, title: "Ahmed's Wishlist" },
    "Wishlist: Ahmed"
  );
  const wishlistZiad = await upsertOne(
    Wishlist,
    { member_mail: ziad.mail, family_id: family._id },
    { member_mail: ziad.mail, family_id: family._id, title: "Ziad's Wishlist" },
    "Wishlist: Ziad"
  );
  const wishlistNoor = await upsertOne(
    Wishlist,
    { member_mail: noor.mail, family_id: family._id },
    { member_mail: noor.mail, family_id: family._id, title: "Noor's Wishlist" },
    "Wishlist: Noor"
  );

  await upsertOne(
    WishlistItem,
    { wishlist_id: wishlistAhmed._id, item_name: 'LEGO City Set' },
    {
      wishlist_id: wishlistAhmed._id,
      category_id: catToys._id,
      item_name: 'LEGO City Set',
      required_points: 220,
      assigned_by: FAMILY_EMAIL,
      description: 'Advanced building kit',
      priority: 1,
      status: 'active',
    },
    'WishlistItem: LEGO City Set'
  );

  await upsertOne(
    WishlistItem,
    { wishlist_id: wishlistZiad._id, item_name: 'Football' },
    {
      wishlist_id: wishlistZiad._id,
      category_id: catToys._id,
      item_name: 'Football',
      required_points: 140,
      assigned_by: FAMILY_EMAIL,
      description: 'Official size football',
      priority: 2,
      status: 'active',
    },
    'WishlistItem: Football'
  );

  await upsertOne(
    WishlistItem,
    { wishlist_id: wishlistNoor._id, item_name: 'STEM Science Kit' },
    {
      wishlist_id: wishlistNoor._id,
      category_id: catLearning._id,
      item_name: 'STEM Science Kit',
      required_points: 180,
      assigned_by: FAMILY_EMAIL,
      description: 'Simple home experiments',
      priority: 1,
      status: 'active',
    },
    'WishlistItem: STEM Science Kit'
  );

  // Redeem data
  console.log('\n=== Redeem Data ===');
  await upsertOne(
    Redeem,
    { requester: ahmed.mail, request_details: 'Redeem LEGO City Set', family_id: family._id },
    {
      family_id: family._id,
      member_id: ahmed._id,
      requester: ahmed.mail,
      approver: FAMILY_EMAIL,
      status: 'pending',
      request_details: 'Redeem LEGO City Set',
      point_deduction: 220,
      payment_method: 'points',
      points_used: 220,
      money_used: 0,
    },
    'Redeem: pending request'
  );

  await upsertOne(
    Redeem,
    { requester: ziad.mail, request_details: 'Redeem Football', family_id: family._id },
    {
      family_id: family._id,
      member_id: ziad._id,
      requester: ziad.mail,
      approver: FAMILY_EMAIL,
      status: 'parent_approved',
      parent_approved_at: daysAgo(1),
      approved_at: daysAgo(1),
      request_details: 'Redeem Football',
      point_deduction: 140,
      payment_method: 'points',
      points_used: 140,
      money_used: 0,
    },
    'Redeem: parent approved'
  );

  await upsertOne(
    Redeem,
    { requester: noor.mail, request_details: 'Redeem STEM Science Kit', family_id: family._id },
    {
      family_id: family._id,
      member_id: noor._id,
      requester: noor.mail,
      approver: FAMILY_EMAIL,
      status: 'rejected',
      rejection_reason: 'Save points a little more',
      request_details: 'Redeem STEM Science Kit',
      point_deduction: 180,
      payment_method: 'points',
      points_used: 180,
      money_used: 0,
    },
    'Redeem: rejected'
  );

  // Grocery
  console.log('\n=== Grocery Data ===');
  const weeklyList = await upsertOne(
    GroceryList,
    { family_id: family._id, title: 'Weekly Grocery - Family' },
    {
      family_id: family._id,
      title: 'Weekly Grocery - Family',
      created_by: FAMILY_EMAIL,
      color: '#43A047',
    },
    'GroceryList: Weekly Grocery - Family'
  );

  await upsertOne(
    GroceryItem,
    { list_id: weeklyList._id, item_name: 'Eggs' },
    {
      list_id: weeklyList._id,
      item_name: 'Eggs',
      quantity: 12,
      unit: 'piece',
      category: 'Protein',
      is_checked: false,
      added_by: FAMILY_EMAIL,
    },
    'GroceryItem: Eggs'
  );

  await upsertOne(
    GroceryItem,
    { list_id: weeklyList._id, item_name: 'Milk' },
    {
      list_id: weeklyList._id,
      item_name: 'Milk',
      quantity: 2,
      unit: 'liter',
      category: 'Dairy',
      is_checked: true,
      added_by: FAMILY_EMAIL,
    },
    'GroceryItem: Milk'
  );

  await upsertOne(
    GroceryItem,
    { list_id: weeklyList._id, item_name: 'Rice' },
    {
      list_id: weeklyList._id,
      item_name: 'Rice',
      quantity: 3,
      unit: 'kg',
      category: 'Grains',
      is_checked: false,
      added_by: FAMILY_EMAIL,
    },
    'GroceryItem: Rice'
  );

  // Receipts
  console.log('\n=== Receipt Data ===');
  await upsertOne(
    Receipt,
    { family_id: family._id, member_mail: FAMILY_EMAIL, store_name: 'Carrefour', total_amount: 760, purchase_date: new Date('2026-05-09') },
    {
      family_id: family._id,
      member_mail: FAMILY_EMAIL,
      total_amount: 760,
      purchase_date: new Date('2026-05-09'),
      store_name: 'Carrefour',
      notes: 'Weekly groceries',
      items: [
        { name: 'Rice', quantity: '2', unit: 'kg', price: 120 },
        { name: 'Milk', quantity: '2', unit: 'liter', price: 80 },
        { name: 'Chicken', quantity: '1.5', unit: 'kg', price: 300 },
      ],
      subtotal: 700,
      taxes: 60,
    },
    'Receipt: Carrefour'
  );

  await upsertOne(
    Receipt,
    { family_id: family._id, member_mail: ahmed.mail, store_name: 'Stationery Hub', total_amount: 95, purchase_date: new Date('2026-05-12') },
    {
      family_id: family._id,
      member_mail: ahmed.mail,
      total_amount: 95,
      purchase_date: new Date('2026-05-12'),
      store_name: 'Stationery Hub',
      notes: 'School supplies',
      items: [
        { name: 'Notebook', quantity: '3', unit: 'piece', price: 45 },
        { name: 'Pen Pack', quantity: '1', unit: 'piece', price: 50 },
      ],
      subtotal: 95,
      taxes: 0,
    },
    'Receipt: Stationery Hub'
  );

  // Location
  console.log('\n=== Location Data ===');
  const locations = [
    { member: parent, lat: 30.0444, lng: 31.2357 },
    { member: ahmed, lat: 30.0501, lng: 31.2402 },
    { member: ziad, lat: 30.0395, lng: 31.2301 },
    { member: noor, lat: 30.0478, lng: 31.2370 },
  ];

  for (const loc of locations) {
    await upsertOne(
      LocationShare,
      { member_mail: loc.member.mail, family_id: family._id },
      {
        member_mail: loc.member.mail,
        family_id: family._id,
        latitude: loc.lat,
        longitude: loc.lng,
        is_sharing_enabled: true,
      },
      `LocationShare: ${loc.member.mail}`
    );
  }

  await upsertOne(
    LocationPermission,
    { requester_mail: ahmed.mail, target_mail: parent.mail, family_id: family._id },
    {
      requester_mail: ahmed.mail,
      target_mail: parent.mail,
      family_id: family._id,
      permission_status: 'approved',
      requested_at: daysAgo(5),
    },
    'LocationPermission: Ahmed -> Parent'
  );

  await upsertOne(
    LocationPermission,
    { requester_mail: noor.mail, target_mail: parent.mail, family_id: family._id },
    {
      requester_mail: noor.mail,
      target_mail: parent.mail,
      family_id: family._id,
      permission_status: 'pending',
      requested_at: daysAgo(1),
    },
    'LocationPermission: Noor -> Parent'
  );

  for (const loc of locations) {
    const historyCount = await LocationHistory.countDocuments({
      member_mail: loc.member.mail,
      family_id: family._id,
    });

    if (historyCount < 3) {
      await LocationHistory.create([
        { member_mail: loc.member.mail, family_id: family._id, latitude: loc.lat, longitude: loc.lng, recorded_at: daysAgo(2) },
        { member_mail: loc.member.mail, family_id: family._id, latitude: loc.lat + 0.002, longitude: loc.lng + 0.002, recorded_at: daysAgo(1) },
        { member_mail: loc.member.mail, family_id: family._id, latitude: loc.lat + 0.003, longitude: loc.lng + 0.001, recorded_at: new Date() },
      ]);
      console.log(`  + Created LocationHistory for ${loc.member.mail}`);
    } else {
      console.log(`  ~ Exists LocationHistory for ${loc.member.mail}`);
    }
  }

  await upsertOne(
    LocationAlert,
    { member_mail: parent.mail, family_id: family._id, alert_type: 'custom', message: 'Ahmed reached school area.' },
    {
      member_mail: parent.mail,
      family_id: family._id,
      alert_type: 'custom',
      message: 'Ahmed reached school area.',
      latitude: 30.0501,
      longitude: 31.2402,
      is_read: false,
    },
    'LocationAlert: custom'
  );

  // Planning conversation
  console.log('\n=== Planning AI Chat Data ===');
  const conv = await PlanningConversation.findOne({ family_id: family._id, member_id: parent._id });
  if (!conv) {
    await PlanningConversation.create({
      family_id: family._id,
      member_id: parent._id,
      messages: [
        { role: 'user', content: 'Can you suggest meals for this week?' },
        { role: 'assistant', content: 'Based on your pantry, I suggest tomato rice, omelette, and green salad.' },
        { role: 'user', content: 'Who is doing best in tasks this week?' },
        { role: 'assistant', content: 'Ahmed currently has the highest recent points.' },
      ],
    });
    console.log('  + Created PlanningConversation');
  } else {
    console.log('  ~ Exists PlanningConversation');
  }

  // Meal suggestions
  console.log('\n=== Meal Suggestions Data ===');
  const recipes = await Recipe.find({ family_id: family._id }).limit(3);
  for (const recipe of recipes) {
    await upsertOne(
      MealSuggestion,
      { family_id: family._id, recipe_id: recipe._id, meal_type: 'Any' },
      {
        family_id: family._id,
        recipe_id: recipe._id,
        meal_type: 'Any',
        match_percentage: 82,
        missing_ingredients: [],
        available_ingredients: ['Rice', 'Tomatoes', 'Onion', 'Olive Oil'],
        uses_expiring_items: true,
        uses_leftovers: false,
      },
      `MealSuggestion: ${recipe.recipe_name}`
    );
  }

  // Inventory alerts
  console.log('\n=== Inventory Alerts Data ===');
  const lowItem = await InventoryItem.findOne({ item_name: 'Bread' });
  const expiringItem = await InventoryItem.findOne({ item_name: 'Milk' });

  if (lowItem) {
    await upsertOne(
      InventoryAlert,
      { inventory_item_id: lowItem._id, alert_type: 'low_stock', family_id: family._id },
      {
        inventory_item_id: lowItem._id,
        family_id: family._id,
        alert_type: 'low_stock',
        alert_message: 'Bread is low in stock.',
        is_read: false,
      },
      'InventoryAlert: low_stock'
    );
  }

  if (expiringItem) {
    await upsertOne(
      InventoryAlert,
      { inventory_item_id: expiringItem._id, alert_type: 'expiring_soon', family_id: family._id },
      {
        inventory_item_id: expiringItem._id,
        family_id: family._id,
        alert_type: 'expiring_soon',
        alert_message: 'Milk will expire soon.',
        is_read: false,
      },
      'InventoryAlert: expiring_soon'
    );
  }

  console.log('\nExtra module seed complete.');
  await mongoose.disconnect();
}

run().catch(async (err) => {
  console.error('Seed extra modules error:', err.message);
  try {
    await mongoose.disconnect();
  } catch (_) {}
  process.exit(1);
});
