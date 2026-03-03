import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000/api';
  
  // Get stored token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }
  
  // Save token
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }
  
  // Get headers with token
  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
  
  // Auth APIs
  Future<Map<String, dynamic>> signup(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      final responseData = jsonDecode(response.body);
      if (responseData['token'] != null) {
        await _saveToken(responseData['token']);
      }
      return responseData;
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Signup failed');
    }
  }
  
  Future<Map<String, dynamic>> login(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['token'] != null) {
        await _saveToken(responseData['token']);
      }
      // Save user data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLogin', responseData['data']['isFirstLogin'] ?? false);
      await prefs.setString('memberType', responseData['data']['memberType'] ?? '');
      await prefs.setString('username', responseData['data']['username'] ?? '');
      await prefs.setString('familyTitle', responseData['data']['familyTitle'] ?? '');
      return responseData;
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Login failed');
    }
  }
  
  // Set/Change Password API
  Future<Map<String, dynamic>> setPassword({
    String? currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final headers = await _getHeaders();
    print('🔵 Setting password...');
    
    final body = {
      'newPassword': newPassword,
      'confirmPassword': confirmPassword,
    };
    
    if (currentPassword != null && currentPassword.isNotEmpty) {
      body['currentPassword'] = currentPassword;
    }
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/setPassword'),
      headers: headers,
      body: jsonEncode(body),
    );
    
    print('🔵 Set password response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      // Clear isFirstLogin flag
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstLogin', false);
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to set password');
    }
  }
  
  // Check if first login
  Future<bool> isFirstLogin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isFirstLogin') ?? false;
  }
  
  // Member APIs
  Future<List<dynamic>> getAllMembers() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/members'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['members'] ?? [];
    } else {
      throw Exception('Failed to load members');
    }
  }
  
  Future<Map<String, dynamic>> createMember(Map<String, dynamic> data) async {
    final token = await _getToken();
    print('🔵 Token for createMember: ${token != null ? "EXISTS" : "NULL - THIS IS THE PROBLEM!"}');
    
    final headers = await _getHeaders();
    print('🔵 Creating member with headers: $headers');
    print('🔵 Member data: $data');
    
    final response = await http.post(
      Uri.parse('$baseUrl/members'),
      headers: headers,
      body: jsonEncode(data),
    );
    
    print('🔵 Response status: ${response.statusCode}');
    print('🔵 Response body: ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create member');
    }
  }
  
  // Member Type APIs
  Future<List<dynamic>> getAllMemberTypes() async {
    final token = await _getToken();
    print('🔵 Token retrieved: ${token != null ? "EXISTS (${token.substring(0, 20)}...)" : "NULL"}');
    
    final headers = await _getHeaders();
    print('🔵 Fetching member types with headers: $headers');
    
    final response = await http.get(
      Uri.parse('$baseUrl/memberTypes'),
      headers: headers,
    );
    
    print('🔵 Member types response status: ${response.statusCode}');
    print('🔵 Member types response body: ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['memberTypes'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load member types');
    }
  }
  
  // Create Member Type API
  Future<Map<String, dynamic>> createMemberType(String typeName) async {
    final headers = await _getHeaders();
    print('🔵 Creating member type: $typeName');
    
    final response = await http.post(
      Uri.parse('$baseUrl/memberTypes'),
      headers: headers,
      body: jsonEncode({'type': typeName}),
    );
    
    print('🔵 Create member type response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create member type');
    }
  }
  
  // Delete Member API
  Future<Map<String, dynamic>> deleteMember(String memberId) async {
    final headers = await _getHeaders();
    print('🔵 Deleting member: $memberId');
    
    final response = await http.delete(
      Uri.parse('$baseUrl/members/$memberId'),
      headers: headers,
    );
    
    print('🔵 Delete member response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete member');
    }
  }
  
  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    await prefs.remove('username');
    await prefs.remove('familyTitle');
    await prefs.remove('isFirstLogin');
  }

  // Deactivate Account
  Future<Map<String, dynamic>> deactivateAccount(String mail, String password) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/familyAccounts/deactivate'),
      headers: headers,
      body: jsonEncode({
        'mail': mail,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to deactivate account');
    }
  }

  // ======================= TASK APIs =======================
  
  // Get all tasks
  Future<List<dynamic>> getAllTasks() async {
    final headers = await _getHeaders();
    print('🔵 Getting all tasks...');
    
    final response = await http.get(
      Uri.parse('$baseUrl/tasks'),
      headers: headers,
    );
    
    print('🔵 Tasks response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['tasks'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load tasks');
    }
  }

  // Create task
  Future<Map<String, dynamic>> createTask(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/tasks'),
      headers: headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create task');
    }
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/tasks/$taskId'),
      headers: headers,
    );
    
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete task');
    }
  }

  // Get my assigned tasks
  Future<List<dynamic>> getMyTasks() async {
    final headers = await _getHeaders();
    print('🔵 Getting my tasks with headers: $headers');
    
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/my-tasks'),
      headers: headers,
    );
    
    print('🔵 Tasks response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['tasks'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load my tasks');
    }
  }

  // Get all assigned tasks (for status view)
  Future<List<dynamic>> getAllAssignedTasks() async {
    final headers = await _getHeaders();
    print('🔵 Getting all assigned tasks (history)...');
    
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/all-assigned'),
      headers: headers,
    );
    
    print('🔵 Assigned tasks response: ${response.statusCode}');
    print('🔵 Assigned tasks body: ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      final tasks = responseData['data']['assignedTasks'] ?? [];
      print('🔵 Found ${tasks.length} assigned tasks');
      return tasks;
    } else {
      throw Exception('Failed to load assigned tasks');
    }
  }

  // Assign task
  Future<Map<String, dynamic>> assignTask(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/assign'),
      headers: headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to assign task');
    }
  }

  // Complete task
  Future<Map<String, dynamic>> completeTask(String taskDetailId) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/tasks/assignments/$taskDetailId/complete'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to complete task');
    }
  }

  // Approve task completion (Parent only)
  Future<Map<String, dynamic>> approveTaskCompletion(String taskDetailId, bool approved) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/tasks/assignments/$taskDetailId/approve-completion'),
      headers: headers,
      body: jsonEncode({'approved': approved}),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to approve task');
    }
  }

  // Get tasks waiting for approval (Parent only)
  Future<List<dynamic>> getTasksWaitingApproval() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/waiting-approval'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['tasksWaitingApproval'] ?? [];
    } else {
      throw Exception('Failed to load tasks waiting approval');
    }
  }

  // ======================= POINT WALLET APIs =======================
  
  // Get my wallet
  Future<Map<String, dynamic>> getMyWallet() async {
    final headers = await _getHeaders();
    print('🔵 Getting wallet with headers: $headers');
    
    final response = await http.get(
      Uri.parse('$baseUrl/point-wallet/my-wallet'),
      headers: headers,
    );
    
    print('🔵 Wallet response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['wallet'] ?? {};
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load wallet');
    }
  }

  // Get points ranking/leaderboard
  Future<List<dynamic>> getPointsRanking() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/point-wallet/ranking'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['ranking'] ?? [];
    } else {
      throw Exception('Failed to load ranking');
    }
  }

  // ======================= POINT HISTORY APIs =======================
  
  // Get my point history
  Future<List<dynamic>> getMyPointHistory() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/point-history/my-history'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['history'] ?? [];
    } else {
      throw Exception('Failed to load point history');
    }
  }

  // ======================= REDEEM APIs =======================
  
  // Request redemption
  Future<Map<String, dynamic>> requestRedemption(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/redeem/request'),
      headers: headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to request redemption');
    }
  }

  // Get my redemptions
  Future<List<dynamic>> getMyRedemptions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/redeem/my-redemptions'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['redemptions'] ?? [];
    } else {
      throw Exception('Failed to load redemptions');
    }
  }

  // Get pending redemptions (Parent only)
  Future<List<dynamic>> getPendingRedemptions() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/redeem/pending'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['redemptions'] ?? [];
    } else {
      throw Exception('Failed to load pending redemptions');
    }
  }

  // Parent approve/reject redemption
  Future<Map<String, dynamic>> parentApproveRedemption(String redeemId, bool approved, {String? note}) async {
    final headers = await _getHeaders();
    final Map<String, dynamic> body = {'approved': approved};
    if (note != null) body['note'] = note;
    
    final response = await http.patch(
      Uri.parse('$baseUrl/redeem/$redeemId/parent-approve'),
      headers: headers,
      body: jsonEncode(body),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to process redemption');
    }
  }

  // Cancel redemption
  Future<void> cancelRedemption(String redeemId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/redeem/$redeemId/cancel'),
      headers: headers,
    );
    
    if (response.statusCode != 200) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to cancel redemption');
    }
  }

  // ======================= TASK CATEGORY APIs =======================
  
  // Get all task categories
  Future<List<dynamic>> getAllTaskCategories() async {
    final headers = await _getHeaders();
    print('🔵 Getting all task categories...');
    
    final response = await http.get(
      Uri.parse('$baseUrl/task-categories'),
      headers: headers,
    );
    
    print('🔵 Categories response: ${response.statusCode} - ${response.body}');
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['categories'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load task categories');
    }
  }

  // Create task category
  Future<Map<String, dynamic>> createTaskCategory(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/task-categories'),
      headers: headers,
      body: jsonEncode(data),
    );
    
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create category');
    }
  }

  // ======================= PENDING ASSIGNMENTS APIs (Parent) =======================
  
  // Get pending task assignments (needs parent approval)
  Future<List<dynamic>> getPendingAssignments() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/tasks/pending-assignments'),
      headers: headers,
    );
    
    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['pendingAssignments'] ?? [];
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to load pending assignments');
    }
  }

  // Approve or reject task assignment (Parent only)
  Future<Map<String, dynamic>> approveTaskAssignment(String taskDetailId, bool approved) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/tasks/assignments/$taskDetailId/approve-assignment'),
      headers: headers,
      body: jsonEncode({'approved': approved}),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to process assignment');
    }
  }

  // Apply manual penalty (Parent only)
  Future<Map<String, dynamic>> applyPenalty(String taskDetailId, int penaltyPoints, {String? notes}) async {
    final headers = await _getHeaders();
    final Map<String, dynamic> body = {'penalty_points': penaltyPoints};
    if (notes != null) body['notes'] = notes;
    
    final response = await http.post(
      Uri.parse('$baseUrl/tasks/assignments/$taskDetailId/penalty'),
      headers: headers,
      body: jsonEncode(body),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to apply penalty');
    }
  }

  // ======================= USER TYPE CHECK =======================
  
  // Check if current user is Parent
  Future<bool> isParent() async {
    final prefs = await SharedPreferences.getInstance();
    final memberType = prefs.getString('memberType');
    return memberType == 'Parent';
  }

  // Get current member type
  Future<String?> getMemberType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('memberType');
  }

  // ======================= UNIT APIs =======================

  // Get all units
  Future<List<dynamic>> getAllUnits() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/units'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['units'] ?? [];
    } else {
      throw Exception('Failed to load units');
    }
  }

  // Seed default units
  Future<Map<String, dynamic>> seedUnits() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/units/seed'),
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to seed units');
    }
  }

  // Create a new unit
  Future<Map<String, dynamic>> createUnit(String unitName, String unitType) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/units'),
      headers: headers,
      body: jsonEncode({'unit_name': unitName, 'unit_type': unitType}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create unit');
    }
  }

  // Update a unit
  Future<Map<String, dynamic>> updateUnit(String unitId, {String? unitName, String? unitType}) async {
    final headers = await _getHeaders();
    final Map<String, dynamic> body = {};
    if (unitName != null) body['unit_name'] = unitName;
    if (unitType != null) body['unit_type'] = unitType;

    final response = await http.patch(
      Uri.parse('$baseUrl/units/$unitId'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update unit');
    }
  }

  // Delete a unit
  Future<void> deleteUnit(String unitId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/units/$unitId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete unit');
    }
  }

  // ======================= INVENTORY APIs =======================

  // Get all inventories
  Future<List<dynamic>> getAllInventories() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/inventory'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['inventories'] ?? [];
    } else {
      throw Exception('Failed to load inventories');
    }
  }

  // Create inventory
  Future<Map<String, dynamic>> createInventory(String title) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/inventory'),
      headers: headers,
      body: jsonEncode({'title': title}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create inventory');
    }
  }

  // Delete inventory
  Future<void> deleteInventory(String inventoryId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/inventory/$inventoryId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete inventory');
    }
  }

  // ======================= ITEM CATEGORY APIs =======================

  // Get all item categories
  Future<List<dynamic>> getAllItemCategories() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/categories'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['categories'] ?? [];
    } else {
      throw Exception('Failed to load item categories');
    }
  }

  // Create item category
  Future<Map<String, dynamic>> createItemCategory(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/categories'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create item category');
    }
  }

  // Delete item category
  Future<void> deleteItemCategory(String categoryId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/inventory/categories/$categoryId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete item category');
    }
  }

  // ======================= INVENTORY ITEM APIs =======================

  // Get all family items (across all inventories)
  Future<List<dynamic>> getAllFamilyItems() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/all-items'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['items'] ?? [];
    } else {
      throw Exception('Failed to load inventory items');
    }
  }

  // Get items in a specific inventory
  Future<Map<String, dynamic>> getInventoryItems(String inventoryId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/$inventoryId/items'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data'] ?? {};
    } else {
      throw Exception('Failed to load inventory items');
    }
  }

  // Add item to inventory
  Future<Map<String, dynamic>> addInventoryItem(String inventoryId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/inventory/$inventoryId/items'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to add item');
    }
  }

  // Update inventory item
  Future<Map<String, dynamic>> updateInventoryItem(String itemId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory/items/$itemId'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update item');
    }
  }

  // Delete inventory item
  Future<void> deleteInventoryItem(String itemId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/inventory/items/$itemId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete item');
    }
  }

  // Get inventory alerts (low stock, expiring, expired)
  Future<Map<String, dynamic>> getInventoryAlerts() async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/inventory/alerts'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data'] ?? {};
    } else {
      throw Exception('Failed to load inventory alerts');
    }
  }

  // ======================= MEAL APIs =======================

  // Get meals (optional: ?date=YYYY-MM-DD or ?start_date=&end_date=)
  Future<List<dynamic>> getMeals({String? date, String? startDate, String? endDate}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/meals';
    final params = <String>[];
    if (date != null) params.add('date=$date');
    if (startDate != null) params.add('start_date=$startDate');
    if (endDate != null) params.add('end_date=$endDate');
    if (params.isNotEmpty) url += '?${params.join('&')}';

    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data']['meals'] ?? [];
    } else {
      throw Exception('Failed to load meals');
    }
  }

  // Get single meal with items
  Future<Map<String, dynamic>> getMeal(String mealId) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$baseUrl/meals/$mealId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['data'] ?? {};
    } else {
      throw Exception('Failed to load meal');
    }
  }

  // Create meal
  Future<Map<String, dynamic>> createMeal(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/meals'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create meal');
    }
  }

  // Update meal
  Future<Map<String, dynamic>> updateMeal(String mealId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/meals/$mealId'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update meal');
    }
  }

  // Delete meal
  Future<void> deleteMeal(String mealId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/meals/$mealId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete meal');
    }
  }

  // Add item to meal (deducts from inventory)
  Future<Map<String, dynamic>> addMealItem(String mealId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/meals/$mealId/items'),
      headers: headers,
      body: jsonEncode(data),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to add meal item');
    }
  }

  // Remove item from meal (restores inventory)
  Future<void> removeMealItem(String mealId, String mealItemId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/meals/$mealId/items/$mealItemId'),
      headers: headers,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to remove meal item');
    }
  }

  // Prepare meal from recipe (auto-deduct all ingredients)
  Future<Map<String, dynamic>> prepareMealFromRecipe(String mealId) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/meals/$mealId/prepare'),
      headers: headers,
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to prepare meal');
    }
  }

  // ==================== RECIPE APIs ====================

  Future<List<dynamic>> getAllRecipes({String? category}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/recipes';
    if (category != null) url += '?category=$category';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['recipes'] ?? [];
    }
    throw Exception('Failed to load recipes');
  }

  Future<Map<String, dynamic>> getRecipe(String recipeId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/recipes/$recipeId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load recipe');
  }

  Future<Map<String, dynamic>> getRecipeScaled(String recipeId, int servings) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/recipes/$recipeId/scaled?servings=$servings'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load scaled recipe');
  }

  Future<Map<String, dynamic>> createRecipe(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/recipes'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to create recipe');
  }

  Future<Map<String, dynamic>> updateRecipe(String recipeId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/recipes/$recipeId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to update recipe');
  }

  Future<void> deleteRecipe(String recipeId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/recipes/$recipeId'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete recipe');
    }
  }

  Future<Map<String, dynamic>> addRecipeIngredient(String recipeId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/recipes/$recipeId/ingredients'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to add ingredient');
  }

  Future<void> removeRecipeIngredient(String recipeId, String ingredientId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/recipes/$recipeId/ingredients/$ingredientId'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to remove ingredient');
    }
  }

  Future<Map<String, dynamic>> addRecipeStep(String recipeId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/recipes/$recipeId/steps'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to add step');
  }

  Future<void> removeRecipeStep(String recipeId, String stepId) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('$baseUrl/recipes/$recipeId/steps/$stepId'),
      headers: headers,
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to remove step');
    }
  }

  // ==================== LEFTOVER APIs ====================

  Future<List<dynamic>> getAllLeftovers({bool? expired}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/leftovers';
    if (expired != null) url += '?expired=$expired';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['leftovers'] ?? [];
    }
    throw Exception('Failed to load leftovers');
  }

  Future<Map<String, dynamic>> addLeftover(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/leftovers'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to add leftover');
  }

  Future<Map<String, dynamic>> updateLeftover(String leftoverId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/leftovers/$leftoverId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to update leftover');
  }

  Future<void> deleteLeftover(String leftoverId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/leftovers/$leftoverId'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete leftover');
    }
  }

  Future<Map<String, dynamic>> getExpiringLeftovers() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/leftovers/expiring'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load expiring leftovers');
  }

  Future<List<dynamic>> getAllLeftoverCategories() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/leftovers/categories'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['categories'] ?? [];
    }
    throw Exception('Failed to load leftover categories');
  }

  Future<Map<String, dynamic>> createLeftoverCategory(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/leftovers/categories'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to create leftover category');
  }

  Future<void> deleteLeftoverCategory(String categoryId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/leftovers/categories/$categoryId'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete leftover category');
    }
  }

  // ==================== MEAL SUGGESTION APIs ====================

  Future<Map<String, dynamic>> generateMealSuggestions() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/meal-suggestions/generate'),
      headers: headers,
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to generate suggestions');
  }

  Future<List<dynamic>> getMealSuggestions() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/meal-suggestions'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['suggestions'] ?? [];
    }
    throw Exception('Failed to load meal suggestions');
  }

  Future<void> clearMealSuggestions() async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/meal-suggestions'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to clear suggestions');
    }
  }

  // ==================== INVENTORY ALERT APIs (Persisted) ====================

  Future<List<dynamic>> getInventoryAlertsPersisted({bool? isRead, String? alertType}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/inventory-alerts';
    List<String> params = [];
    if (isRead != null) params.add('is_read=$isRead');
    if (alertType != null) params.add('alert_type=$alertType');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['alerts'] ?? [];
    }
    throw Exception('Failed to load alerts');
  }

  Future<int> getUnreadAlertCount() async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/inventory-alerts/unread-count'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['unreadCount'] ?? 0;
    }
    throw Exception('Failed to load unread count');
  }

  Future<void> markAlertAsRead(String alertId) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory-alerts/$alertId/read'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark alert as read');
    }
  }

  Future<void> markAllAlertsAsRead() async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory-alerts/mark-all-read'),
      headers: headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to mark all as read');
    }
  }

  Future<void> deleteAlert(String alertId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/inventory-alerts/$alertId'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete alert');
    }
  }

  Future<Map<String, dynamic>> generateInventoryAlerts() async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/inventory-alerts/generate'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to generate alerts');
  }

  // ==================== RECEIPT APIs ====================

  Future<List<dynamic>> getAllReceipts({String? startDate, String? endDate, String? memberMail}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/receipts';
    List<String> params = [];
    if (startDate != null) params.add('start_date=$startDate');
    if (endDate != null) params.add('end_date=$endDate');
    if (memberMail != null) params.add('member_mail=$memberMail');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['receipts'] ?? [];
    }
    throw Exception('Failed to load receipts');
  }

  Future<Map<String, dynamic>> getReceipt(String receiptId) async {
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse('$baseUrl/receipts/$receiptId'), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load receipt');
  }

  Future<Map<String, dynamic>> createReceipt(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/receipts'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to create receipt');
  }

  Future<Map<String, dynamic>> updateReceipt(String receiptId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/receipts/$receiptId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to update receipt');
  }

  Future<void> deleteReceipt(String receiptId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/receipts/$receiptId'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete receipt');
    }
  }

  Future<Map<String, dynamic>> getSpendingSummary({String? startDate, String? endDate}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/receipts/summary';
    List<String> params = [];
    if (startDate != null) params.add('start_date=$startDate');
    if (endDate != null) params.add('end_date=$endDate');
    if (params.isNotEmpty) url += '?${params.join('&')}';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    throw Exception('Failed to load spending summary');
  }

  // ==================== INVENTORY CATEGORY APIs ====================

  Future<List<dynamic>> getAllInventoryCategories({bool tree = false}) async {
    final headers = await _getHeaders();
    String url = '$baseUrl/inventory-categories';
    if (tree) url += '?tree=true';
    final response = await http.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['categories'] ?? [];
    }
    throw Exception('Failed to load inventory categories');
  }

  Future<Map<String, dynamic>> createInventoryCategory(Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse('$baseUrl/inventory-categories'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to create category');
  }

  Future<Map<String, dynamic>> updateInventoryCategory(String categoryId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory-categories/$categoryId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to update category');
  }

  Future<void> deleteInventoryCategory(String categoryId) async {
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse('$baseUrl/inventory-categories/$categoryId'), headers: headers);
    if (response.statusCode != 200 && response.statusCode != 204) {
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete category');
    }
  }

  // ==================== ITEM CATEGORY UPDATE (was missing) ====================

  Future<Map<String, dynamic>> updateItemCategory(String categoryId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory/categories/$categoryId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to update item category');
  }

  // ==================== INVENTORY UPDATE (was missing) ====================

  Future<Map<String, dynamic>> updateInventory(String inventoryId, Map<String, dynamic> data) async {
    final headers = await _getHeaders();
    final response = await http.patch(
      Uri.parse('$baseUrl/inventory/$inventoryId'),
      headers: headers,
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    }
    final errorData = jsonDecode(response.body);
    throw Exception(errorData['message'] ?? 'Failed to update inventory');
  }
}
