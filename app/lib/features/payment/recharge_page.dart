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

    // 显示订单确认弹窗
    final pkg = _packages.firstWhere((p) => p['price'] == _selectedAmount);
    final total = _selectedAmount + (pkg['bonus'] as int);
    final priceYuan = _selectedAmount ~/ 10;

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Center(child: Text('确认充值')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department, size: 48, color: AppTheme.primary),
            const SizedBox(height: 12),
            Text('${pkg['label']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primary)),
            const SizedBox(height: 4),
            if ((pkg['bonus'] as int) > 0)
              Text('赠送 ${pkg['bonus']} 根', style: const TextStyle(fontSize: 14, color: Colors.red)),
            const SizedBox(height: 12),
            Text('实付: ¥$priceYuan', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text('充值后会直接到账 ${total} 根柴火🔥', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                  const SizedBox(height: 8),
                  Text('支付方式: XorPay 扫码支付', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('正在跳转支付页面...'), backgroundColor: AppTheme.primary),
              );
              // TODO: 接入 XorPay/PayJS 支付
              Future.delayed(const Duration(seconds: 1), () {
                if (mounted) {
                  showDialog(
                    context: context,
                    builder: (ctx2) => AlertDialog(
                      title: const Text('支付测试'),
                      content: const Text('XorPay 支付正在对接中，预计下一版本上线。\n\n当前为演示模式，点击确认模拟到账。'),
                      actions: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx2);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('充值成功！到账 $total 根柴火🔥')),
                            );
                          },
                          child: const Text('模拟支付成功'),
                        ),
                      ],
                    ),
                  );
                }
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text('确认支付 ¥$priceYuan'),
          ),
        ],
      ),
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
