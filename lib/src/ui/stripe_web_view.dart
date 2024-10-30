import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class StripeWebView extends StatefulWidget {
  const StripeWebView({Key? key, required this.uri, required this.returnUri})
      : super(key: key);

  final String uri;
  final Uri returnUri;

  @override
  State<StripeWebView> createState() => _StripeWebViewState();
}

class _StripeWebViewState extends State<StripeWebView> {
  WebViewController? controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {},
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.parse(request.url);
            if (uri.scheme == widget.returnUri.scheme &&
                uri.host == widget.returnUri.host &&
                uri.queryParameters['requestId'] ==
                    widget.returnUri.queryParameters['requestId']) {
              Navigator.pop(context, true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(
        widget.uri,
      ));
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null) return SizedBox();
    //return WebViewWidget(controller: controller)
    return WebViewWidget(
      controller: controller!,
    );
  }
}
