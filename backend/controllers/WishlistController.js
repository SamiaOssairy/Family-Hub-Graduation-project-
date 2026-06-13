const AppError = require("../utils/appError");
const { catchAsync } = require("../utils/catchAsync");
const Wishlist = require("../models/wishlistModel");
const WishlistItem = require("../models/wishlist_itemModel");
const WishlistCategory = require("../models/wishlist_categoryModel");
const Member = require("../models/MemberModel");

// Resolve a wishlist category id. If a category_id is given, verify it belongs
// to the family. If none is given, find-or-create a shared "General" category so
// any member can add items even when no categories were set up by a parent.
// Returns the category ObjectId, or null after calling next(err).
async function resolveWishlistCategory(category_id, familyId, next) {
  if (category_id) {
    const category = await WishlistCategory.findOne({ _id: category_id, family_id: familyId });
    if (!category) {
      next(new AppError("Category not found or doesn't belong to your family", 404));
      return null;
    }
    return category._id;
  }
  let general = await WishlistCategory.findOne({ family_id: familyId, title: 'General' });
  if (!general) {
    general = await WishlistCategory.create({ family_id: familyId, title: 'General' });
  }
  return general._id;
}

//========================================================================================
// Get my wishlist
exports.getMyWishlist = catchAsync(async (req, res, next) => {
  let wishlist = await Wishlist.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
  
  if (!wishlist) {
    // Create wishlist if doesn't exist
    wishlist = await Wishlist.create({ 
      member_mail: req.member.mail,
      family_id: req.familyAccount._id,
      title: 'My Wishlist'
    });
  }
  
  // Get wishlist items
  const items = await WishlistItem.find({ 
    wishlist_id: wishlist._id,
    status: 'active'
  })
    .populate('category_id')
    .populate('assigned_by', 'username mail')
    .sort({ priority: -1, createdAt: -1 });
  
  res.status(200).json({
    status: "success",
    data: { 
      wishlist,
      items 
    }
  });
});

//========================================================================================
// Get specific member's wishlist (Parent can view any child's wishlist)
exports.getMemberWishlist = catchAsync(async (req, res, next) => {
  const { memberMail } = req.params;
  
  // Verify member belongs to family
  const member = await Member.findOne({ 
    mail: memberMail, 
    family_id: req.familyAccount._id 
  });
  
  if (!member) {
    return next(new AppError("Member not found in your family", 404));
  }
  
  let wishlist = await Wishlist.findOne({ member_mail: memberMail, family_id: req.familyAccount._id });
  
  if (!wishlist) {
    wishlist = await Wishlist.create({ 
      member_mail: memberMail,
      family_id: req.familyAccount._id,
      title: `${member.username}'s Wishlist`
    });
  }
  
  const items = await WishlistItem.find({ 
    wishlist_id: wishlist._id,
    status: 'active'
  })
    .populate('category_id')
    .populate('assigned_by', 'username mail')
    .sort({ priority: -1, createdAt: -1 });
  
  res.status(200).json({
    status: "success",
    data: { 
      wishlist,
      items,
      memberInfo: {
        username: member.username,
        mail: member.mail
      }
    }
  });
});

//========================================================================================
// Add item to wishlist
exports.addWishlistItem = catchAsync(async (req, res, next) => {
  const { item_name, required_points, category_id, description, priority } = req.body;

  if (!item_name || required_points === undefined || required_points === null) {
    return next(new AppError("Please provide item_name and required_points", 400));
  }

  // Resolve the category: use the provided one, or fall back to a shared
  // "General" category (auto-created) so members who can't manage categories
  // can still add wishlist items.
  const categoryId = await resolveWishlistCategory(category_id, req.familyAccount._id, next);
  if (!categoryId) return; // resolveWishlistCategory already sent the error

  // Get or create wishlist
  let wishlist = await Wishlist.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
  if (!wishlist) {
    wishlist = await Wishlist.create({
      member_mail: req.member.mail,
      family_id: req.familyAccount._id,
      title: 'My Wishlist'
    });
  }

  const newItem = await WishlistItem.create({
    wishlist_id: wishlist._id,
    category_id: categoryId,
    item_name,
    required_points,
    assigned_by: req.member.mail,
    description: description || '',
    priority: priority || 0,
    status: 'active'
  });
  
  await newItem.populate('category_id');
  
  res.status(201).json({
    status: "success",
    data: { item: newItem }
  });
});

//========================================================================================
// Add item to member's wishlist (Parent can add to any child's wishlist)
exports.addWishlistItemToMember = catchAsync(async (req, res, next) => {
  const { memberMail } = req.params;
  const { item_name, required_points, category_id, description, priority } = req.body;

  if (!item_name || required_points === undefined || required_points === null) {
    return next(new AppError("Please provide item_name and required_points", 400));
  }

  // Verify member belongs to family
  const member = await Member.findOne({
    mail: memberMail,
    family_id: req.familyAccount._id
  });

  if (!member) {
    return next(new AppError("Member not found in your family", 404));
  }

  const categoryId = await resolveWishlistCategory(category_id, req.familyAccount._id, next);
  if (!categoryId) return;

  // Get or create wishlist
  let wishlist = await Wishlist.findOne({ member_mail: memberMail, family_id: req.familyAccount._id });
  if (!wishlist) {
    wishlist = await Wishlist.create({
      member_mail: memberMail,
      family_id: req.familyAccount._id,
      title: `${member.username}'s Wishlist`
    });
  }

  const newItem = await WishlistItem.create({
    wishlist_id: wishlist._id,
    category_id: categoryId,
    item_name,
    required_points,
    assigned_by: req.member.mail,
    description: description || '',
    priority: priority || 0,
    status: 'active'
  });
  
  await newItem.populate('category_id');
  
  res.status(201).json({
    status: "success",
    message: `Item added to ${member.username}'s wishlist`,
    data: { item: newItem }
  });
});

//========================================================================================
// Update wishlist item (modify points or priority)
exports.updateWishlistItem = catchAsync(async (req, res, next) => {
  const { itemId } = req.params;
  const { item_name, required_points, description, priority, category_id } = req.body;
  
  const item = await WishlistItem.findById(itemId)
    .populate('wishlist_id');
  
  if (!item) {
    return next(new AppError("Wishlist item not found", 404));
  }
  
  // Verify wishlist belongs to family member
  const member = await Member.findOne({ 
    mail: item.wishlist_id.member_mail, 
    family_id: req.familyAccount._id 
  });
  
  if (!member) {
    return next(new AppError("This item doesn't belong to your family", 403));
  }
  
  // Member can only update their own items, Parent can update anyone's
  const MemberType = require("../models/MemberTypeModel");
  const memberType = await MemberType.findById(req.member.member_type_id);
  
  if (memberType.type !== 'Parent' && item.wishlist_id.member_mail !== req.member.mail) {
    return next(new AppError("You can only update your own wishlist items", 403));
  }
  
  if (item_name) item.item_name = item_name;
  if (required_points !== undefined) item.required_points = required_points;
  if (description !== undefined) item.description = description;
  if (priority !== undefined) item.priority = priority;
  if (category_id) {
    const category = await WishlistCategory.findOne({ 
      _id: category_id, 
      family_id: req.familyAccount._id 
    });
    if (!category) {
      return next(new AppError("Category not found", 404));
    }
    item.category_id = category_id;
  }
  
  await item.save();
  await item.populate('category_id');
  
  res.status(200).json({
    status: "success",
    data: { item }
  });
});

//========================================================================================
// Prioritize wishlist items (reorder)
exports.prioritizeWishlistItems = catchAsync(async (req, res, next) => {
  const { itemPriorities } = req.body; // Array of { itemId, priority }
  
  if (!Array.isArray(itemPriorities)) {
    return next(new AppError("Please provide an array of itemPriorities", 400));
  }
  
  // Get wishlist
  const wishlist = await Wishlist.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
  if (!wishlist) {
    return next(new AppError("Wishlist not found", 404));
  }
  
  // Update priorities
  const updatePromises = itemPriorities.map(async ({ itemId, priority }) => {
    const item = await WishlistItem.findOne({ 
      _id: itemId, 
      wishlist_id: wishlist._id 
    });
    if (item) {
      item.priority = priority;
      await item.save();
    }
  });
  
  await Promise.all(updatePromises);
  
  // Get updated items
  const items = await WishlistItem.find({ 
    wishlist_id: wishlist._id,
    status: 'active'
  })
    .populate('category_id')
    .sort({ priority: -1 });
  
  res.status(200).json({
    status: "success",
    message: "Wishlist priorities updated",
    data: { items }
  });
});

//========================================================================================
// Remove item from wishlist
exports.removeWishlistItem = catchAsync(async (req, res, next) => {
  const { itemId } = req.params;
  
  const item = await WishlistItem.findById(itemId)
    .populate('wishlist_id');
  
  if (!item) {
    return next(new AppError("Wishlist item not found", 404));
  }
  
  // Verify wishlist belongs to family member
  const member = await Member.findOne({ 
    mail: item.wishlist_id.member_mail, 
    family_id: req.familyAccount._id 
  });
  
  if (!member) {
    return next(new AppError("This item doesn't belong to your family", 403));
  }
  
  // Member can only remove their own items, Parent can remove anyone's
  const MemberType = require("../models/MemberTypeModel");
  const memberType = await MemberType.findById(req.member.member_type_id);
  
  if (memberType.type !== 'Parent' && item.wishlist_id.member_mail !== req.member.mail) {
    return next(new AppError("You can only remove your own wishlist items", 403));
  }
  
  item.status = 'removed';
  await item.save();
  
  res.status(200).json({
    status: "success",
    message: "Item removed from wishlist"
  });
});

//========================================================================================
// View progress towards wishlist goals
exports.getWishlistProgress = catchAsync(async (req, res, next) => {
  const PointWallet = require("../models/point_walletModel");
  
  let wishlist = await Wishlist.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
  if (!wishlist) {
    return next(new AppError("Wishlist not found", 404));
  }
  
  const wallet = await PointWallet.findOne({ member_mail: req.member.mail, family_id: req.familyAccount._id });
  const currentPoints = wallet ? wallet.total_points : 0;
  
  const items = await WishlistItem.find({ 
    wishlist_id: wishlist._id,
    status: 'active'
  })
    .populate('category_id')
    .sort({ priority: -1 });
  
  const itemsWithProgress = items.map(item => ({
    ...item.toObject(),
    current_points: currentPoints,
    progress_percentage: Math.min(100, (currentPoints / item.required_points) * 100).toFixed(2),
    points_needed: Math.max(0, item.required_points - currentPoints),
    can_redeem: currentPoints >= item.required_points
  }));
  
  res.status(200).json({
    status: "success",
    data: { 
      current_points: currentPoints,
      items: itemsWithProgress
    }
  });
});
