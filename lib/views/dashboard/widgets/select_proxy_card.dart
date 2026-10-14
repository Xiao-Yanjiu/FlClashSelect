import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/views/proxies/card.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class SelectProxyCard extends ConsumerStatefulWidget {
  const SelectProxyCard({super.key});

  @override
  ConsumerState<SelectProxyCard> createState() => _SelectProxyCardState();
}

class _SelectProxyCardState extends ConsumerState<SelectProxyCard> {
  final _search = TextEditingController();
  String _groupName = 'GLOBAL';
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.appLocalizations;
    final groups = ref.watch(visibleGroupsStateProvider).value;
    final group =
        groups.getGroup(_groupName) ?? (groups.isEmpty ? null : groups.first);
    final testing =
        group != null &&
        ref.watch(
          delayTestingGroupsProvider.select(
            (state) => state.contains(group.name),
          ),
        );
    final groupNames = ref
        .watch(groupsProvider)
        .map((item) => item.name)
        .toSet();
    final nodes =
        group?.all
            .where(
              (node) =>
                  !groupNames.contains(node.name) &&
                  !{
                    'direct',
                    'reject',
                    'reject-drop',
                    'pass',
                    'selector',
                    'urltest',
                    'fallback',
                    'loadbalance',
                    'load-balance',
                  }.contains(node.type.toLowerCase()) &&
                  !{
                    'DIRECT',
                    'REJECT',
                    'REJECT-DROP',
                    'PASS',
                  }.contains(node.name.toUpperCase()) &&
                  node.name.toLowerCase().contains(_query.toLowerCase()),
            )
            .toList() ??
        [];
    final delays = <String, int?>{};
    for (final node in nodes) {
      delays[node.name] = ref.watch(
        delayProvider(proxyName: node.name, testUrl: group?.testUrl),
      );
    }
    nodes.removeWhere(
      (node) => delays[node.name] != null && delays[node.name]! <= 0,
    );
    nodes.sort((a, b) {
      final left = delays[a.name], right = delays[b.name];
      if (left == null && right == null) return a.name.compareTo(b.name);
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    });
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 2),
      child: CommonCard(
        radius: DashboardWidgetMetrics.radiusOf(context),
        child: Padding(
          padding: DashboardWidgetMetrics.paddingOf(
            context,
          ).copyWith(top: 8, bottom: 8),
          child: Column(
            children: [
              Row(
                children: [
                  Text(l.proxies, style: context.textTheme.bodySmall),
                  const SizedBox(width: 8),
                  if (group != null)
                    Expanded(
                      flex: 2,
                      child: DropdownButton<String>(
                        isExpanded: true,
                        isDense: true,
                        value: group.name,
                        items: [
                          for (final item in groups)
                            DropdownMenuItem(
                              value: item.name,
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.textTheme.bodySmall,
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) setState(() => _groupName = value);
                        },
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _search,
                      onChanged: (value) => setState(() => _query = value),
                      style: context.textTheme.bodySmall,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l.search,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l.delayTest,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                    onPressed: group == null || testing
                        ? null
                        : () => ref
                              .read(proxiesActionProvider.notifier)
                              .delayTestPageGroup(group.name),
                    icon: const GlyphIcon(AppGlyphs.bolt, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: group == null
                    ? Center(child: Text(l.nullTip(l.proxies)))
                    : LayoutBuilder(
                        builder: (context, constraints) => GridView.builder(
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisExtent: (constraints.maxHeight - 6) / 2,
                                crossAxisSpacing: 6,
                                mainAxisSpacing: 6,
                              ),
                          itemCount: nodes.length,
                          itemBuilder: (context, index) => ProxyCard(
                            key: ValueKey('${group.name}:${nodes[index].name}'),
                            groupName: group.name,
                            testUrl: group.testUrl,
                            proxy: nodes[index],
                            groupType: group.type,
                            type: ProxyCardType.min,
                            showSpeed: false,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
