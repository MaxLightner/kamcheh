import 'dart:typed_data';
import 'package:flutter/material.dart';

class ListingGallery extends StatefulWidget {
  const ListingGallery(
      {super.key,
      this.photos = const [],
      this.assets = const [],
      this.height = 200});
  final List<Uint8List> photos;
  final List<String> assets;
  final double height;
  @override
  State<ListingGallery> createState() => _ListingGalleryState();
}

class _ListingGalleryState extends State<ListingGallery> {
  int index = 0;
  late final controller = PageController();
  int get count => widget.photos.length + widget.assets.length;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Widget photo(int i, BoxFit fit) => i < widget.photos.length
      ? Image.memory(widget.photos[i],
          fit: fit,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined))
      : Image.asset(
          'assets/images/${widget.assets[i - widget.photos.length]}.jpg',
          fit: fit);
  Future<void> enlarge(int initial) async {
    final enlargedController = PageController(initialPage: initial);
    await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog.fullscreen(
                child: SafeArea(
                    child: Column(children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                      tooltip: 'بستن گالری',
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close))),
              Expanded(
                  child: PageView.builder(
                      controller: enlargedController,
                      itemCount: count,
                      itemBuilder: (_, i) =>
                          InteractiveViewer(child: photo(i, BoxFit.contain)))),
              const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('برای دیدن عکس‌های دیگر ورق بزنید.')),
            ]))));
    enlargedController.dispose();
  }

  String faCount(int n) =>
      n.toString().split('').map((d) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(d)]).join();
  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Column(children: [
      ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
              height: widget.height,
              child: Stack(fit: StackFit.expand, children: [
                PageView.builder(
                    controller: controller,
                    itemCount: count,
                    onPageChanged: (v) => setState(() => index = v),
                    itemBuilder: (_, i) => InkWell(
                        onTap: () => enlarge(i),
                        child: photo(i, BoxFit.cover))),
                Positioned(
                    bottom: 8,
                    left: 8,
                    child: DecoratedBox(
                        decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6)),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            child: Text(
                                '${faCount(index + 1)} / ${faCount(count)}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11))))),
                if (count > 1)
                  Positioned(
                      right: 4,
                      top: widget.height / 2 - 22,
                      child: IconButton.filledTonal(
                          tooltip: 'عکس قبل',
                          onPressed: index > 0
                              ? () => controller.previousPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut)
                              : null,
                          icon: const Icon(Icons.chevron_right))),
                if (count > 1)
                  Positioned(
                      left: 4,
                      top: widget.height / 2 - 22,
                      child: IconButton.filledTonal(
                          tooltip: 'عکس بعد',
                          onPressed: index < count - 1
                              ? () => controller.nextPage(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut)
                              : null,
                          icon: const Icon(Icons.chevron_left))),
              ]))),
      if (count > 1)
        Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
                spacing: 5,
                children: List.generate(
                    count,
                    (i) => Container(
                        width: i == index ? 14 : 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: i == index
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4)))))),
    ]);
  }
}
