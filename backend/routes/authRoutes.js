const express = require("express");


const { signUp, login, forgotPassword, resetPassword, protect, restrictTo, setPassword, getFamiliesByMail } = require("../controllers/AuthController");

const authRouter = express.Router();
authRouter.post("/signup", signUp);
authRouter.post("/login", login);
authRouter.get("/families", getFamiliesByMail);

// Password reset — MUST be public: a user who forgot their password cannot log in.
// The reset link carries its own one-time token, so resetPassword is self-authenticating.
authRouter.post("/forgotPassword", forgotPassword);
authRouter.patch("/resetPassword/:token", resetPassword);

// Protected routes - for all logged-in users
authRouter.use(protect);

// Set/Change password - available to all members
authRouter.post("/setPassword", setPassword);

// Parent only routes
authRouter.use(restrictTo("Parent"));

module.exports = authRouter;








