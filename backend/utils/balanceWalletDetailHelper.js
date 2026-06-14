const BalanceWalletDetail = require('../models/balanceWalletDetailModel');

const recordBalanceWalletDetail = async (payload) => {
	if (!payload || !payload.family_id || !payload.member_mail) {
		return null;
	}

	return BalanceWalletDetail.create({
		wallet_scope: 'money_wallet',
		change_type: 'credit',
		source_type: 'manual_adjustment',
		amount: 0,
		previous_balance: 0,
		new_balance: 0,
		...payload,
	});
};

module.exports = {
	recordBalanceWalletDetail,
};