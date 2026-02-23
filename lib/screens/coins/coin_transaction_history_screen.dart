import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/coin_service.dart';
import '../../constants/app_constants.dart';

class CoinTransactionHistoryScreen extends StatefulWidget {
  const CoinTransactionHistoryScreen({Key? key}) : super(key: key);

  @override
  State<CoinTransactionHistoryScreen> createState() => _CoinTransactionHistoryScreenState();
}

class _CoinTransactionHistoryScreenState extends State<CoinTransactionHistoryScreen> {
  final CoinService _coinService = CoinService();
  
  bool _isLoading = true;
  List<Map<String, dynamic>> _transactions = [];
  int _offset = 0;
  final int _limit = 20;
  bool _hasMoreData = true;
  num _coinBalance = 0;
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        _loadMoreTransactions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _offset = 0;
      _hasMoreData = true;
    });
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.id;
    
    if (userId != null) {
      final transactions = await _coinService.getTransactionHistory(
        userId, 
        limit: _limit, 
        offset: _offset
      );
      final coinBalance = await _coinService.getUserCoins(userId);
      
      if (mounted) {
        setState(() {
          _transactions = transactions;
          _coinBalance = coinBalance;
          _isLoading = false;
          _offset += transactions.length;
          _hasMoreData = transactions.length == _limit;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (!_hasMoreData || _isLoading) return;
    
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.user?.id;
    
    if (userId != null) {
      setState(() {
        _isLoading = true;
      });
      
      final moreTransactions = await _coinService.getTransactionHistory(
        userId, 
        limit: _limit, 
        offset: _offset
      );
      
      if (mounted) {
        setState(() {
          _transactions.addAll(moreTransactions);
          _isLoading = false;
          _offset += moreTransactions.length;
          _hasMoreData = moreTransactions.length == _limit;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coin Transactions'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTransactions,
        child: Column(
          children: [
            // Coin balance card
            _buildCoinBalanceCard(),
            
            // Transactions list
            Expanded(
              child: _isLoading && _transactions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _transactions.isEmpty
                      ? _buildEmptyState()
                      : _buildTransactionList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCoinBalanceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Icon(
              Icons.monetization_on,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current Balance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_coinBalance coins',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Could navigate to a screen showing coin earning opportunities
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Earn coins by completing goals and challenges!'),
                ),
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.background,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Earn More'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: AppTextStyles.bodyBold,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Complete goals and challenges to earn coins!',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTransactionList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _transactions.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _transactions.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        final transaction = _transactions[index];
        return _buildTransactionCard(transaction);
      },
    );
  }
  
  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final amount = transaction['amount'] as num;
    final description = transaction['description'] as String;
    final transactionType = transaction['transaction_type'] as String;
    final createdAt = DateTime.parse(transaction['created_at'] as String);
    
    // Format date
    final dateFormat = DateFormat('MMM d, yyyy • h:mm a');
    final formattedDate = dateFormat.format(createdAt);
    
    // Determine icon and color based on transaction type
    IconData icon;
    Color color;
    
    if (amount > 0) {
      // Earned coins
      icon = Icons.add_circle;
      color = Colors.green;
    } else {
      // Spent coins
      icon = Icons.remove_circle;
      color = Colors.red;
    }
    
    // Get more specific icon based on transaction type
    switch (transactionType) {
      case 'goal_creation':
      case 'goal_completion':
        icon = Icons.check_circle;
        break;
      case 'challenge_completion':
        icon = Icons.emoji_events;
        break;
      case 'subscription_bonus':
        icon = Icons.card_membership;
        break;
      case 'premium_purchase':
        icon = Icons.shopping_cart;
        break;
      default:
        // Use default icons set above
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Transaction icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            // Transaction details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: AppTextStyles.bodyBold,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formattedDate,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Transaction amount
            Text(
              (amount > 0 ? '+' : '') + amount.toString(),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
