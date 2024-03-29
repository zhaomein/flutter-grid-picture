import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

//ignore: must_be_immutable
class EasyListView extends StatefulWidget {

  EasyListView({
    @required this.itemCount,
    @required this.itemBuilder,
    this.headerBuilder,
    this.footerBuilder,
    this.loadMore = false,
    this.onLoadMore,
    this.loadMoreWhenNoData = false,
    this.loadMoreItemBuilder,
    this.dividerBuilder,
    this.physics,
    this.headerSliverBuilder,
    this.controller,
    this.foregroundWidget,
    this.padding,
    this.scrollbarEnable = true, 
    this.reverse = false,
    // [Not Recommended]
    // Sliver mode will discard a lot of ListView variables (likes physics, controller),
    // and each of items must be sliver.
    // *Sliver mode will build all items when inited. (ListView item is built by lazy)*
  }):assert(itemBuilder != null);
  
  ScrollController controller;
  final int itemCount;
  final WidgetBuilder headerBuilder;
  final WidgetBuilder footerBuilder;
  final WidgetBuilder loadMoreItemBuilder;
  final IndexedWidgetBuilder itemBuilder;
  final IndexedWidgetBuilder dividerBuilder;
  final bool loadMore;
  final bool loadMoreWhenNoData;
  final bool reverse;
  final bool scrollbarEnable;
  final VoidCallback onLoadMore;
  final ScrollPhysics physics;
  final NestedScrollViewHeaderSliversBuilder headerSliverBuilder;
  final Widget foregroundWidget;
  final EdgeInsetsGeometry padding;

  @override
  State<StatefulWidget> createState() => EasyListViewState();
}

enum ItemType { header, footer, loadMore, data, dividerData }

class EasyListViewState extends State<EasyListView> {

    @override
  void initState() {
    super.initState();
  }

  bool get isNested => widget.headerSliverBuilder != null;

  @override
  Widget build(BuildContext context) =>  _buildList();

  Widget _itemBuilder(context, index) {
    var headerCount = _headerCount();
    var totalItemCount = _dataItemCount() + headerCount + _footerCount();
    switch (_itemType(index, totalItemCount)) {
      case ItemType.header:
        return widget.headerBuilder(context);
      case ItemType.footer:
        return widget.footerBuilder(context);
      case ItemType.loadMore:
        return _buildLoadMoreItem();
      case ItemType.dividerData:
        return _buildDividerWithData(index, index - headerCount);
      case ItemType.data:
      default:
        return widget.itemBuilder(context, index - headerCount);
    }
  }

  _buildList() {
    var headerCount = _headerCount();
    var totalItemCount = _dataItemCount() + headerCount + _footerCount();

    ScrollView listView =  ListView.builder(
      physics: isNested ? null : widget.physics,
      controller: isNested ? null : widget.controller,
      padding: widget.padding,
      itemCount: totalItemCount,
      reverse: widget.reverse,
      itemBuilder: _itemBuilder,
    );

    List<Widget> children = widget.scrollbarEnable ? [Scrollbar(child: listView)] : [listView];
    if (widget.foregroundWidget != null) children.add(widget.foregroundWidget);
    return Stack(children: children);
  }

  ItemType _itemType(itemIndex, totalItemCount) {
    if (_isHeader(itemIndex)) {
      return ItemType.header;
    } else if (_isLoadMore(itemIndex, totalItemCount)) {
      return ItemType.loadMore;
    } else if (_isFooter(itemIndex, totalItemCount)) {
      return ItemType.footer;
    } else if (_hasDivider()) {
      return ItemType.dividerData;
    } else {
      return ItemType.data;
    }
  }

  Widget _buildLoadMoreItem() {
    if ((widget.loadMoreWhenNoData ||
            (!widget.loadMoreWhenNoData && widget.itemCount > 0)) &&
        widget.onLoadMore != null) {
      Timer(Duration(milliseconds: 50), widget.onLoadMore);
    }
    return widget.loadMoreItemBuilder != null
        ? widget.loadMoreItemBuilder(context)
        :_defaultLoadMore;
  }

  Widget _buildDividerWithData(index, dataIndex) => index.isEven
      ? widget.dividerBuilder != null
          ? widget.dividerBuilder(context, dataIndex ~/ 2)
          : _defaultDivider
      : widget.itemBuilder(context, dataIndex ~/ 2);

  bool _isHeader(itemIndex) => _hasHeader() && itemIndex == 0;

  bool _isLoadMore(itemIndex, total) =>
      widget.loadMore && itemIndex == total - 1;

  bool _isFooter(itemIndex, total) => _hasFooter() && itemIndex == total - 1;

  int _headerCount() => _hasHeader() ? 1 : 0;

  int _footerCount() => (_hasFooter() || widget.loadMore) ? 1 : 0;

  int _dataItemCount() =>
      _hasDivider() ? widget.itemCount * 2 - 1 : widget.itemCount;

  bool _hasDivider() => widget.dividerBuilder != null;

  bool _hasHeader() => widget.headerBuilder != null;

  bool _hasFooter() => widget.footerBuilder != null;

  final _defaultLoadMore = Container(
    padding: const EdgeInsets.all(8.0),
    color: Colors.white,
    child: Center(
      child: SizedBox(
        width: 25,
        height: 25,
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        )
      )
    ),
  );

  final _defaultDivider = const Divider(color: Colors.grey);
}