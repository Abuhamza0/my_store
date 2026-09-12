// lib/features/store_service/orders_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/store_id_service.dart';

class OrdersPage extends StatefulWidget {
  final String initialFilter;

  const OrdersPage({
    super.key,
    this.initialFilter = 'all',
  });

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  static const Color _navy = Color(0xFF0B1220);
  static const Color _navy2 = Color(0xFF14213A);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldSoft = Color(0xFFF4E7B5);

  String filterStatus = 'all';
  String searchQuery = '';
  bool _isRefreshing = false;
  late final String _storeId;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _ordersStream;

  final TextEditingController _searchController = TextEditingController();

  String _getStoreId() => StoreIdService.getStoreId();

  @override
  void initState() {
    super.initState();
    filterStatus = _validFilter(widget.initialFilter)
        ? widget.initialFilter
        : 'all';

    _storeId = _getStoreId().trim();

    if (_storeId.isNotEmpty) {
      _ordersStream = FirebaseFirestore.instance
          .collection('orders')
          .where('store_id', isEqualTo: _storeId)
          .snapshots();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _validFilter(String value) {
    return const {
      'all',
      'pending',
      'preparing',
      'ready',
      'delivered',
      'cancelled',
    }.contains(value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final storeId = _storeId;

    if (storeId.isEmpty) {
      return _buildInvalidStore(context, isDark);
    }

    if (_ordersStream == null) {
      _ordersStream = FirebaseFirestore.instance
          .collection('orders')
          .where('store_id', isEqualTo: _storeId)
          .snapshots();
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070C16) : const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _ordersStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildErrorState(snapshot.error, isDark);
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return _buildLoadingState(isDark);
                  }

                  final orders = snapshot.hasData
                      ? snapshot.data!.docs
                      .map(
                        (doc) => _OrderRecord(
                      id: doc.id,
                      data: doc.data(),
                    ),
                  )
                      .toList()
                      : <_OrderRecord>[];

                  orders.sort(
                        (a, b) => _dateOf(b.data['createdAt'])
                        .compareTo(_dateOf(a.data['createdAt'])),
                  );

                  final counts = _buildCounts(orders);
                  final filtered = _filterOrders(orders);

                  return Column(
                    children: [
                      _buildSummaryHeader(
                        isDark,
                        counts,
                        orders.length,
                        filtered.length,
                      ),
                      _buildFilters(isDark, counts),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState(isDark)
                            : _buildOrdersBody(
                          context,
                          filtered,
                          storeId,
                          isDark,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [_navy2, _navy],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.30 : 0.16),
            blurRadius: 18,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildHeaderIcon(
                icon: Icons.arrow_back_rounded,
                tooltip: 'back'.tr,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 12),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withOpacity(0.45)),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: _gold,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'orders_management'.tr,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'orders_subtitle'.tr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.60),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _buildHeaderIcon(
                icon: Icons.refresh_rounded,
                tooltip: 'refresh'.tr,
                loading: _isRefreshing,
                onTap: _refresh,
              ),
              const SizedBox(width: 6),
              _buildHeaderIcon(
                icon: Icons.search_rounded,
                tooltip: 'search'.tr,
                onTap: () {
                  FocusScope.of(context).requestFocus(FocusNode());
                  _showSearchDialog(context, isDark);
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.075),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => searchQuery = value.trim().toLowerCase());
              },
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
              ),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _gold,
                  size: 21,
                ),
                hintText: 'search_orders_hint'.tr,
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 12,
                ),
                suffixIcon: searchQuery.isEmpty
                    ? null
                    : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withOpacity(0.55),
                    size: 19,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: loading ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.10),
            ),
          ),
          child: loading
              ? const Padding(
            padding: EdgeInsets.all(11),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_gold),
            ),
          )
              : Icon(
            icon,
            color: Colors.white.withOpacity(0.88),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryHeader(
      bool isDark,
      Map<String, int> counts,
      int total,
      int visible,
      ) {
    final pending = counts['pending'] ?? 0;
    final active = (counts['preparing'] ?? 0) + (counts['ready'] ?? 0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildWelcomeCard(isDark, total, visible),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        isDark,
                        'new_orders'.tr,
                        pending,
                        Icons.notifications_active_rounded,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildMiniStat(
                        isDark,
                        'in_progress'.tr,
                        active,
                        Icons.autorenew_rounded,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildWelcomeCard(isDark, total, visible),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  isDark,
                  'new_orders'.tr,
                  pending,
                  Icons.notifications_active_rounded,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMiniStat(
                  isDark,
                  'in_progress'.tr,
                  active,
                  Icons.autorenew_rounded,
                  Colors.blue,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWelcomeCard(bool isDark, int total, int visible) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [_navy2, Color(0xFF182642)]
              : const [Color(0xFF17243B), Color(0xFF263B5E)],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.15),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shopping_bag_rounded,
              color: _gold,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'incoming_orders'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  visible == total
                      ? '$total ${'orders_in_store'.tr}'
                      : '${'showing'.tr} $visible ${'from'.tr} $total ${'orders'.tr}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$total',
            style: const TextStyle(
              color: _gold,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
      bool isDark,
      String title,
      int count,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111A2B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.06) : const Color(0xFFE8EBF0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.10 : 0.045),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.11),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count',
                  style: TextStyle(
                    color: isDark ? Colors.white : _navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark, Map<String, int> counts) {
    final filters = <Map<String, dynamic>>[
      {'label': 'all'.tr, 'value': 'all', 'icon': Icons.apps_rounded},
      {'label': 'status_pending'.tr, 'value': 'pending', 'icon': Icons.fiber_new_rounded},
      {'label': 'status_preparing'.tr, 'value': 'preparing', 'icon': Icons.inventory_2_rounded},
      {'label': 'status_ready'.tr, 'value': 'ready', 'icon': Icons.check_circle_rounded},
      {'label': 'status_delivered'.tr, 'value': 'delivered', 'icon': Icons.done_all_rounded},
      {'label': 'status_cancelled'.tr, 'value': 'cancelled', 'icon': Icons.cancel_rounded},
    ];

    return SizedBox(
      height: 57,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 7, 16, 7),
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = filters[index];
          return _buildFilterChip(
            isDark,
            item['label'] as String,
            item['value'] as String,
            item['icon'] as IconData,
            counts[item['value'] as String] ?? 0,
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(
      bool isDark,
      String label,
      String value,
      IconData icon,
      int count,
      ) {
    final selected = filterStatus == value;

    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => setState(() => filterStatus = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected
              ? _navy
              : (isDark ? const Color(0xFF111A2B) : Colors.white),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: selected
                ? _gold.withOpacity(0.70)
                : (isDark
                ? Colors.white.withOpacity(0.07)
                : const Color(0xFFE4E8EF)),
          ),
          boxShadow: selected
              ? [
            BoxShadow(
              color: _gold.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: selected
                  ? _gold
                  : (isDark ? Colors.white54 : Colors.black45),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black38),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              constraints: const BoxConstraints(minWidth: 22),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: selected ? _gold : (isDark ? Colors.white10 : const Color(0xFFEFF1F5)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _navy : (isDark ? Colors.white70 : Colors.black54),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersBody(
      BuildContext context,
      List<_OrderRecord> orders,
      String storeId,
      bool isDark,
      ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: orders.length,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildOrderCard(
          context,
          orders[index],
          storeId,
          isDark,
        ),
      ),
    );
  }

  Widget _buildOrderCard(
      BuildContext context,
      _OrderRecord order,
      String storeId,
      bool isDark,
      ) {
    final data = order.data;
    final status = _statusOf(data);
    final customerName = _string(data['customerName'], 'customer'.tr);
    final customerPhone = _string(data['customerPhone']);
    final total = _number(data['totalAmount']);
    final items = _itemsOf(data);
    final notes = _string(data['notes']);
    final createdAt = _dateOf(data['createdAt']);
    final statusInfo = _statusInfo(status);
    final unread = data['isRead'] == false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101827) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unread
              ? _gold.withOpacity(0.42)
              : (isDark ? Colors.white.withOpacity(0.055) : const Color(0xFFE7EAF0)),
          width: unread ? 1.2 : 1,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: statusInfo.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(statusInfo.icon, color: statusInfo.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerName,
                        style: TextStyle(
                          color: isDark ? Colors.white : _navy,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (customerPhone.isNotEmpty)
                        Text(
                          customerPhone,
                          style: TextStyle(
                            color: isDark ? Colors.white38 : Colors.black45,
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
                _buildStatusBadge(statusInfo),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${items.length} ${'products_count'.tr}',
                        style: TextStyle(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatMoney(total)} ${'currency_symbol'.tr}',
                      style: TextStyle(
                        color: isDark ? Colors.white : _navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildActionArea(context, order, storeId, status, isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerAvatar(String name, Color color) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return Container(
      width: 43,
      height: 43,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.70),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.20),
            blurRadius: 8,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(_StatusInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: info.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: info.color.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.icon, color: info.color, size: 13),
          const SizedBox(width: 4),
          Text(
            info.label,
            style: TextStyle(
              color: info.color,
              fontSize: 9,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasketPreview(
      BuildContext context,
      List<Map<String, dynamic>> items,
      bool isDark,
      ) {
    final visible = items.take(2).toList();
    final remaining = items.length - visible.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1523) : const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.055)
              : const Color(0xFFE9ECF1),
        ),
      ),
      child: items.isEmpty
          ? Row(
        children: [
          Icon(
            Icons.remove_shopping_cart_outlined,
            size: 17,
            color: isDark ? Colors.white30 : Colors.black26,
          ),
          const SizedBox(width: 7),
          Text(
            'no_product_details'.tr,
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.black38,
              fontSize: 10,
            ),
          ),
        ],
      )
          : Column(
        children: [
          for (int i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Divider(
                height: 9,
                color: isDark ? Colors.white10 : Colors.black12,
              ),
            Row(
              children: [
                Container(
                  width: 27,
                  height: 27,
                  decoration: BoxDecoration(
                    color: _gold.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.shopping_bag_outlined,
                    color: _gold,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _string(
                      visible[i]['productName'] ?? visible[i]['name'],
                      'product'.tr,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white70 : _navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '×${_number(visible[i]['quantity']).toInt()}',
                  style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black45,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
          if (remaining > 0) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '+ $remaining ${'more_products'.tr} — ${'view_full_cart'.tr}',
                style: const TextStyle(
                  color: _gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoItem(bool isDark, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white38 : Colors.black38,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(
      BuildContext context,
      _OrderRecord order,
      String storeId,
      String status,
      bool isDark,
      ) {
    final children = <Widget>[
      Expanded(
        child: _buildSecondaryButton(
          isDark,
          icon: Icons.shopping_bag_outlined,
          label: 'view_cart'.tr,
          onTap: () => _showOrderDetails(context, order.data),
        ),
      ),
    ];

    if (status == 'pending') {
      children.add(const SizedBox(width: 7));
      children.add(
        Expanded(
          child: _buildPrimaryButton(
            icon: Icons.play_arrow_rounded,
            label: 'start_preparing'.tr,
            color: Colors.blue,
            onTap: () => _changeStatus(
              order.id,
              'preparing',
              storeId,
            ),
          ),
        ),
      );
    } else if (status == 'preparing') {
      children.add(const SizedBox(width: 7));
      children.add(
        Expanded(
          child: _buildPrimaryButton(
            icon: Icons.check_rounded,
            label: 'status_ready'.tr,
            color: Colors.green,
            onTap: () => _changeStatus(
              order.id,
              'ready',
              storeId,
            ),
          ),
        ),
      );
    } else if (status == 'ready') {
      children.add(const SizedBox(width: 7));
      children.add(
        Expanded(
          child: _buildPrimaryButton(
            icon: Icons.done_all_rounded,
            label: 'status_delivered'.tr,
            color: Colors.teal,
            onTap: () => _changeStatus(
              order.id,
              'delivered',
              storeId,
            ),
          ),
        ),
      );
    }

    return Row(children: children);
  }

  Widget _buildSecondaryButton(
      bool isDark, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      height: 39,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.white70 : _navy,
          side: BorderSide(
            color: isDark
                ? Colors.white.withOpacity(0.10)
                : const Color(0xFFDCE1E8),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 39,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15, color: Colors.white),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 7),
        ),
      ),
    );
  }

  void _showOrderDetails(
      BuildContext context,
      Map<String, dynamic> data,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _itemsOf(data);
    final total = _number(data['totalAmount']);
    final customerName = _string(data['customerName'], 'customer'.tr);
    final orderId = _string(data['orderId']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0E1625) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_rounded,
                            color: _gold,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'cart_details'.tr,
                                style: TextStyle(
                                  color: isDark ? Colors.white : _navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customerName +
                                    (orderId.isEmpty ? '' : ' • #$orderId'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.black45,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                  Expanded(
                    child: items.isEmpty
                        ? _buildSheetEmpty(isDark)
                        : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: 9),
                      itemBuilder: (_, index) {
                        return _buildCartItem(
                          sheetContext, // ✅ تمرير context
                          items[index],
                          index + 1,
                          isDark,
                        );
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111A2B)
                          : const Color(0xFFFAFAFB),
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFE9EBEF),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'total_label'.tr,
                          style: TextStyle(
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatMoney(total),
                          style: TextStyle(
                            color: isDark ? Colors.white : _navy,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'currency_symbol'.tr,
                          style: const TextStyle(
                            color: _gold,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartItem(
      BuildContext context,
      Map<String, dynamic> item,
      int index,
      bool isDark,
      ) {
    final name = _string(
      item['productName'] ?? item['name'] ?? item['title'],
      'product'.tr,
    );
    final price = _number(item['price']);
    final quantity = _number(item['quantity']).toInt();
    final total = _number(
      item['total'] ?? item['subtotal'] ?? item['lineTotal'],
      fallback: price * quantity,
    );
    final productId = _string(item['productId']);
    final imagePath = _string(item['imagePath'] ?? item['image'] ?? item['productImage']);

    return GestureDetector(
      onTap: () => _showProductDetailsFromCloud(context, productId, item, isDark),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF121C2E) : const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE9ECF1),
          ),
        ),
        child: Row(
          children: [
            // ✅ صورة المنتج - نجلبها من السحابة إذا لم تكن موجودة
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 50,
                height: 50,
                child: _buildProductImage(
                  productId: productId,
                  imagePath: imagePath,
                  isDark: isDark,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isDark ? Colors.white : _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatMoney(price)} ${'currency_symbol'.tr} × $quantity',
                    style: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black45,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_formatMoney(total)} ${'currency_symbol'.tr}',
                  style: TextStyle(
                    color: isDark ? Colors.white : _navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: _gold.withOpacity(0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage({
    required String productId,
    required String imagePath,
    required bool isDark,
  }) {
    // إذا كانت الصورة موجودة في بيانات الطلب، استخدمها مباشرة
    if (imagePath.isNotEmpty && (imagePath.startsWith('http') || imagePath.startsWith('https'))) {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(isDark),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return _buildProductImagePlaceholder(isDark);
        },
      );
    }

    // إذا لم تكن الصورة موجودة، نجلبها من Firestore
    if (productId.isNotEmpty) {
      return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        future: FirebaseFirestore.instance
            .collection('products')
            .doc(productId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildProductImagePlaceholder(isDark);
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return _buildProductImagePlaceholder(isDark);
          }

          final productData = snapshot.data!.data() ?? {};
          final cloudImagePath = _string(
            productData['imagePath'] ?? productData['image'],
          );

          if (cloudImagePath.isEmpty) {
            return _buildProductImagePlaceholder(isDark);
          }

          return Image.network(
            cloudImagePath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(isDark),
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _buildProductImagePlaceholder(isDark);
            },
          );
        },
      );
    }

    return _buildProductImagePlaceholder(isDark);
  }

  Widget _buildProductImagePlaceholder(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [Color(0xFF1A2332), Color(0xFF0D1523)]
              : const [Color(0xFFF0F2F5), Color(0xFFE4E8EF)],
        ),
      ),
      child: Icon(
        Icons.shopping_bag_rounded,
        color: _gold.withOpacity(0.5),
        size: 22,
      ),
    );
  }

  Future<void> _showProductDetailsFromCloud(
      BuildContext context,
      String productId,
      Map<String, dynamic> orderItem,
      bool isDark,
      ) async {
    if (productId.isEmpty) {
      // إذا لم يكن هناك productId، اعرض البيانات المتوفرة من الطلب فقط
      _showProductDetailsDialog(context, orderItem, null, isDark);
      return;
    }

    try {
      // ✅ جلب المنتج من Firestore
      final productDoc = await FirebaseFirestore.instance
          .collection('products')
          .doc(productId)
          .get();

      if (!productDoc.exists) {
        // المنتج غير موجود في السحابة، اعرض بيانات الطلب
        _showProductDetailsDialog(context, orderItem, null, isDark);
        return;
      }

      final productData = productDoc.data() ?? {};
      _showProductDetailsDialog(context, orderItem, productData, isDark);
    } catch (e) {
      debugPrint('Error fetching product: $e');
      // في حالة الخطأ، اعرض بيانات الطلب فقط
      _showProductDetailsDialog(context, orderItem, null, isDark);
    }
  }

  void _showProductDetailsDialog(
      BuildContext context,
      Map<String, dynamic> orderItem,
      Map<String, dynamic>? productData,
      bool isDark,
      ) {
    final name = _string(
      productData?['name'] ?? orderItem['productName'] ?? orderItem['name'],
      'product'.tr,
    );
    final description = _string(
      productData?['description'] ?? orderItem['description'],
      'no_description'.tr,
    );
    final price = _number(productData?['price'] ?? orderItem['price']);
    final stock = _toInt(productData?['stock'] ?? 0);
    final category = _string(productData?['category']);
    final flavor = _string(productData?['flavor']);

    // ✅ جمع الصور
    final images = <String>[];
    final mainImage = _string(
      productData?['imagePath'] ?? productData?['image'] ?? orderItem['imagePath'],
    );
    if (mainImage.isNotEmpty) {
      images.add(mainImage);
    }

    final additionalImages = productData?['additionalImages'];
    if (additionalImages is List) {
      for (final img in additionalImages) {
        final imgPath = img?.toString().trim() ?? '';
        if (imgPath.isNotEmpty && !images.contains(imgPath)) {
          images.add(imgPath);
        }
      }
    }

    final quantity = _number(orderItem['quantity']).toInt();
    final total = _number(
      orderItem['total'] ?? orderItem['subtotal'] ?? orderItem['lineTotal'],
      fallback: price * quantity,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF121C2E) : Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                // ✅ معرض الصور
                if (images.isNotEmpty)
                  SizedBox(
                    height: 220,
                    child: PageView.builder(
                      itemCount: images.length,
                      itemBuilder: (_, imgIndex) {
                        return Image.network(
                          images[imgIndex],
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildProductImagePlaceholder(isDark),
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return _buildProductImagePlaceholder(isDark);
                          },
                        );
                      },
                    ),
                  )
                else
                  SizedBox(
                    height: 220,
                    child: _buildProductImagePlaceholder(isDark),
                  ),

                // ✅ معلومات المنتج
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: isDark ? Colors.white : _navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _gold.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_formatMoney(price)} ${'currency_symbol'.tr}',
                                style: const TextStyle(
                                  color: _gold,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),

                        if (flavor.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '🍹 $flavor',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        if (category.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            '📂 $category',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontSize: 11,
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 15),

                        // ✅ معلومات الطلب
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withOpacity(0.05)
                                : const Color(0xFFF7F8FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'quantity_ordered'.tr,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '×$quantity',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : _navy,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Divider(
                                height: 1,
                                color: isDark ? Colors.white10 : Colors.black12,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Text(
                                    'line_total'.tr,
                                    style: TextStyle(
                                      color: isDark ? Colors.white54 : Colors.black45,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_formatMoney(total)} ${'currency_symbol'.tr}',
                                    style: TextStyle(
                                      color: _gold,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              if (stock > 0) ...[
                                const SizedBox(height: 6),
                                Divider(
                                  height: 1,
                                  color: isDark ? Colors.white10 : Colors.black12,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'available_stock'.tr,
                                      style: TextStyle(
                                        color: isDark ? Colors.white54 : Colors.black45,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      '$stock',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ زر الإغلاق
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'close'.tr,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  int _toInt(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildSheetEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.remove_shopping_cart_outlined,
            size: 52,
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          const SizedBox(height: 10),
          Text(
            'cart_empty'.tr,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStatus(
      String orderId,
      String newStatus,
      String storeId,
      ) async {
    if (orderId.trim().isEmpty) return;

    try {
      final orderRef =
      FirebaseFirestore.instance.collection('orders').doc(orderId);
      final orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        _showMessage('order_not_found'.tr, error: true);
        return;
      }

      final data = orderDoc.data() ?? <String, dynamic>{};
      final customerId = _string(data['customerId']);
      final customerPhone = _string(data['customerPhone']);
      final customerToken = _string(data['customerToken']);

      await orderRef.update({
        'status': newStatus,
        'isRead': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await _createNotification(
        storeId: storeId,
        customerId: customerId,
        customerPhone: customerPhone,
        customerToken: customerToken,
        orderId: orderId,
        status: newStatus,
      );

      await SystemSound.play(SystemSoundType.alert);
      _showMessage('order_status_updated'.tr);
    } catch (e) {
      debugPrint('OrdersPage._changeStatus error: $e');
      _showMessage('order_update_error'.tr, error: true);
    }
  }

  Future<void> _sendReadyNotification(
      String orderId,
      String storeId,
      ) async {
    try {
      final orderRef =
      FirebaseFirestore.instance.collection('orders').doc(orderId);
      final orderDoc = await orderRef.get();

      if (!orderDoc.exists) {
        _showMessage('order_not_found'.tr, error: true);
        return;
      }

      final data = orderDoc.data() ?? <String, dynamic>{};

      await _createNotification(
        storeId: storeId,
        customerId: _string(data['customerId']),
        customerPhone: _string(data['customerPhone']),
        customerToken: _string(data['customerToken']),
        orderId: orderId,
        status: 'ready',
      );

      await SystemSound.play(SystemSoundType.alert);
      _showMessage('ready_notification_sent'.tr);
    } catch (e) {
      debugPrint('OrdersPage._sendReadyNotification error: $e');
      _showMessage('notification_send_error'.tr, error: true);
    }
  }

  Future<void> _createNotification({
    required String storeId,
    required String customerId,
    required String customerPhone,
    required String customerToken,
    required String orderId,
    required String status,
  }) async {
    await FirebaseFirestore.instance.collection('notifications').add({
      'storeId': storeId,
      'customerId': customerId,
      'customerPhone': customerPhone,
      'customerToken': customerToken,
      'title': _getStatusTitle(status),
      'body': _getStatusBody(status),
      'orderId': orderId,
      'status': status,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _getStatusTitle(String status) {
    switch (status) {
      case 'preparing':
        return 'order_preparing_title'.tr;
      case 'ready':
        return 'order_ready_title'.tr;
      case 'delivered':
        return 'order_delivered_title'.tr;
      case 'cancelled':
        return 'order_cancelled_title'.tr;
      default:
        return 'order_update'.tr;
    }
  }

  String _getStatusBody(String status) {
    switch (status) {
      case 'preparing':
        return 'order_preparing_body'.tr;
      case 'ready':
        return 'order_ready_body'.tr;
      case 'delivered':
        return 'order_delivered_body'.tr;
      case 'cancelled':
        return 'order_cancelled_body'.tr;
      default:
        return 'order_status_updated_body'.tr;
    }
  }

  Future<void> _refresh() async {
    if (_isRefreshing || !mounted) return;

    setState(() => _isRefreshing = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _showSearchDialog(
      BuildContext context,
      bool isDark,
      ) async {
    final controller = TextEditingController(text: _searchController.text);

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF111A2B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'search_orders'.tr,
            style: TextStyle(
              color: isDark ? Colors.white : _navy,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(
              color: isDark ? Colors.white : _navy,
            ),
            decoration: InputDecoration(
              hintText: 'search_orders_hint'.tr,
              prefixIcon: const Icon(Icons.search_rounded, color: _gold),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withOpacity(0.05)
                  : const Color(0xFFF5F6F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide.none,
              ),
            ),
            onSubmitted: (_) => Navigator.pop(dialogContext),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                _searchController.text = controller.text;
                setState(() => searchQuery = controller.text.trim().toLowerCase());
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
              ),
              child: Text('search'.tr),
            ),
          ],
        );
      },
    );

    controller.dispose();
  }

  List<_OrderRecord> _filterOrders(List<_OrderRecord> orders) {
    return orders.where((order) {
      final status = _statusOf(order.data);

      if (filterStatus != 'all' && status != filterStatus) {
        return false;
      }

      if (searchQuery.isEmpty) {
        return true;
      }

      final searchable = [
        order.id,
        _string(order.data['orderId']),
        _string(order.data['customerName']),
        _string(order.data['customerPhone']),
      ].join(' ').toLowerCase();

      return searchable.contains(searchQuery);
    }).toList();
  }

  Map<String, int> _buildCounts(List<_OrderRecord> orders) {
    final counts = <String, int>{
      'all': orders.length,
      'pending': 0,
      'preparing': 0,
      'ready': 0,
      'delivered': 0,
      'cancelled': 0,
    };

    for (final order in orders) {
      final status = _statusOf(order.data);
      counts[status] = (counts[status] ?? 0) + 1;
    }

    return counts;
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Padding(
              padding: EdgeInsets.all(17),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(_gold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'loading_orders'.tr,
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final hasSearch = searchQuery.isNotEmpty;
    final title = hasSearch
        ? 'no_results'.tr
        : filterStatus == 'all'
        ? 'no_orders_yet'.tr
        : 'no_orders_status'.tr;

    final subtitle = hasSearch
        ? 'try_different_search'.tr
        : 'orders_will_appear_here'.tr;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.09),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasSearch
                    ? Icons.search_off_rounded
                    : Icons.receipt_long_outlined,
                color: _gold.withOpacity(0.75),
                size: 38,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : _navy,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black45,
                fontSize: 11,
              ),
            ),
            if (hasSearch) ...[
              const SizedBox(height: 15),
              OutlinedButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => searchQuery = '');
                },
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: Text('clear_search'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(Object? error, bool isDark) {
    debugPrint('OrdersPage stream error: $error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: Colors.red.withOpacity(0.65),
            ),
            const SizedBox(height: 12),
            Text(
              'orders_load_error'.tr,
              style: TextStyle(
                color: isDark ? Colors.white : _navy,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'check_internet'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white38 : Colors.black45,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvalidStore(BuildContext context, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070C16) : const Color(0xFFF5F7FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.store_mall_directory_outlined,
                color: _gold,
                size: 56,
              ),
              const SizedBox(height: 14),
              Text(
                'store_not_identified'.tr,
                style: TextStyle(
                  color: isDark ? Colors.white : _navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'store_id_not_found'.tr,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black45,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _StatusInfo _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return _StatusInfo(
          'status_pending'.tr,
          Colors.orange,
          Icons.fiber_new_rounded,
        );
      case 'preparing':
        return _StatusInfo(
          'status_preparing'.tr,
          Colors.blue,
          Icons.inventory_2_rounded,
        );
      case 'ready':
        return _StatusInfo(
          'status_ready'.tr,
          Colors.green,
          Icons.check_circle_rounded,
        );
      case 'delivered':
        return _StatusInfo(
          'status_delivered'.tr,
          Colors.teal,
          Icons.done_all_rounded,
        );
      case 'cancelled':
        return _StatusInfo(
          'status_cancelled'.tr,
          Colors.red,
          Icons.cancel_rounded,
        );
      default:
        return _StatusInfo(
          'unknown'.tr,
          Colors.grey,
          Icons.help_outline_rounded,
        );
    }
  }

  String _statusOf(Map<String, dynamic> data) {
    var status = _string(
      data['status'] ?? data['orderStatus'] ?? data['order_status'],
      'pending',
    ).trim().toLowerCase();

    const aliases = <String, String>{
      'new': 'pending',
      'جديد': 'pending',
      'pending': 'pending',
      'preparing': 'preparing',
      'processing': 'preparing',
      'تجهيز': 'preparing',
      'قيد التجهيز': 'preparing',
      'ready': 'ready',
      'جاهز': 'ready',
      'delivered': 'delivered',
      'completed': 'delivered',
      'complete': 'delivered',
      'تم التسليم': 'delivered',
      'cancelled': 'cancelled',
      'canceled': 'cancelled',
      'ملغى': 'cancelled',
      'ملغي': 'cancelled',
    };

    return aliases[status] ?? status;
  }

  List<Map<String, dynamic>> _itemsOf(Map<String, dynamic> data) {
    final raw = data['items'] ?? data['cartItems'] ?? data['orderItems'];
    if (raw is! List) return [];

    return raw.whereType<Map>().map((item) {
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  DateTime _dateOf(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is num) {
      final milliseconds = value > 100000000000
          ? value.toInt()
          : value.toInt() * 1000;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }

    final parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(DateTime date) {
    if (date.millisecondsSinceEpoch == 0) return 'time_unspecified'.tr;

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'now'.tr;
    if (difference.inMinutes < 60) return '${'minutes_ago'.tr} ${difference.inMinutes}';
    if (difference.inHours < 24) return '${'hours_ago'.tr} ${difference.inHours}';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String _formatMoney(num value) {
    final number = value.toDouble();
    if (number == number.roundToDouble()) {
      return number.toInt().toString();
    }
    return number.toStringAsFixed(2);
  }

  double _number(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String _string(dynamic value, [String fallback = '']) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    Get.snackbar(
      error ? 'error'.tr : 'done'.tr,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(14),
      borderRadius: 13,
      backgroundColor: error ? Colors.red.shade700 : _navy,
      colorText: Colors.white,
      icon: Icon(
        error ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
        color: error ? Colors.white : _gold,
      ),
      duration: const Duration(seconds: 2),
    );
  }
}

class _OrderRecord {
  final String id;
  final Map<String, dynamic> data;

  const _OrderRecord({
    required this.id,
    required this.data,
  });
}

class _StatusInfo {
  final String label;
  final Color color;
  final IconData icon;

  const _StatusInfo(
      this.label,
      this.color,
      this.icon,
      );
}