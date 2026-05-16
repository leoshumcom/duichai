import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/theme/app_theme.dart';

class RechargePage extends StatefulWidget {
  final bool isAdPurchase;
  const RechargePage({super.key, this.isAdPurchase = false});

  @override
  State<RechargePage> createState() => _RechargePageState();
}

class _RechargePageState extends State<RechargePage> {
  final _api = Dio(BaseOptions(baseUrl: 'https://api.duichai.com'));
  int _selectedAmount = 0;

  final _packages = [
    {'label': '60根', 'price': 60, 'bonus': 0},
    {'label': '300根', 'price': 300, 'bonus': 10},
    {'label': '600根', 'price': 600, 'bonus': 30},
    {'label': '1280根', 'price': 1280, 'bonus': 80},
    {'label': '3280根', 'price': 3280, 'bonus': 300},
    {'label': '6480根', 'price': 6480, 'bonus': 800},
  ];

  Future<void> _recharge() async {
    if (_selectedAmount <= 0) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('跳转支付中... 金额: ${_selectedAmount ~/ 10}元')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isAdPurchase ? '购买置顶' : '充值柴火';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: AppTheme.primary, size: 32),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('当前柴火', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        const Text('-- 根', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (!widget.isAdPurchase) ...[
              const Text('选择充值套餐', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('1元 = 10根柴火', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const SizedBox(height: 16),
              ..._packages.map((pkg) {
                final isSelected = _selectedAmount == pkg['price'] as int;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => setState(() => _selectedAmount = pkg['price'] as int),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Radio<int>(
                            value: pkg['price'] as int,
                            groupValue: _selectedAmount,
                            onChanged: (v) => setState(() => _selectedAmount = v!),
                            activeColor: AppTheme.primary,
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(pkg['label'] as String,
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    if ((pkg['bonus'] as int) > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 8),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('+${pkg['bonus']}赠送',
                                            style: TextStyle(fontSize: 11, color: Colors.red.shade600)),
                                      ),
                                  ],
                                ),
                                Text(
                                  '${(pkg['price'] as int) ~/ 10}元',
                                  style: const TextStyle(fontSize: 20, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('推荐', style: TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _selectedAmount > 0 ? _recharge : null,
                icon: const Icon(Icons.payment),
                label: Text(widget.isAdPurchase ? '去支付' : '充值 $_selectedAmount 根柴火'),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('支付说明', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Text('充值通过第三方支付平台完成', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  Text('柴火到账后不可退款', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  Text('如有问题请联系客服', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
