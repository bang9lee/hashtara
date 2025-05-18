import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class PhotoViewScreen extends StatelessWidget {
  final String imageUrl;
  final int initialIndex;
  final List<String> imageUrls;

  const PhotoViewScreen({
    Key? key,
    required this.imageUrl,
    this.initialIndex = 0,
    this.imageUrls = const [],
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 상태바 스타일을 설정 (투명한 검은색 배경에 흰색 아이콘)
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    
    // 여러 이미지가 있는 경우 페이지 뷰 사용, 그렇지 않으면 단일 이미지 표시
    final List<String> images = imageUrls.isNotEmpty ? imageUrls : [imageUrl];
    
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: Stack(
        children: [
          // 이미지 페이지 뷰
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  // 한번 탭하면 앱바와 바텀바 토글
                  // 여기서는 간단히 뒤로가기
                },
                onDoubleTap: () {
                  // 더블 탭으로 확대/축소 가능하게 할 수 있음 (추가 구현 필요)
                },
                child: Center(
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(
                      images[index],
                      fit: BoxFit.contain,
                      loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) {
                          return child;
                        }
                        return const Center(
                          child: CupertinoActivityIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(
                            CupertinoIcons.photo,
                            size: 50,
                            color: CupertinoColors.systemGrey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          
          // 닫기 버튼
          Positioned(
            top: 40,
            left: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(128), // 0.5 opacity is alpha 128
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.clear,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
          
          // 현재 이미지 인덱스 표시 (여러 이미지가 있는 경우에만)
          if (images.length > 1)
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(128), // 0.5 opacity is alpha 128
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${initialIndex + 1}/${images.length}',
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}