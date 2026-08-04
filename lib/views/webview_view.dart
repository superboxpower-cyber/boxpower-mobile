import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class WebViewView extends StatefulWidget {
  const WebViewView({super.key});

  @override
  State<WebViewView> createState() => _WebViewViewState();
}

class _WebViewViewState extends State<WebViewView> {
  InAppWebViewController? _webViewController;
  final CookieManager _cookieManager = CookieManager.instance();

  bool _isFlowActive = false;
  double _webLoadingProgress = 0.0;
  bool _showWebProgress = true;
  String _activeEmail = '';

  DateTime? _lastDownloadTime;
  String? _lastDownloadHash;

  final String _dashboardUrl = 'https://boxpower.store/mobile';
  final String _targetUrl = 'https://boxpower.store/fx/pt/tools/flow';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isFlowActive) {
          await _returnToDashboard();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF0C0E14),
          leading: _isFlowActive
              ? IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: _returnToDashboard,
                  tooltip: 'Voltar ao Painel',
                )
              : null,
          title: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF151821),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1F222E)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isFlowActive ? Icons.lock : Icons.dashboard_outlined,
                  color: _isFlowActive ? Colors.greenAccent : theme.colorScheme.primary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  _isFlowActive ? 'Google Flow' : 'Boxpower Portal',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          centerTitle: true,
          actions: _isFlowActive
              ? [
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                    onPressed: _returnToDashboard,
                    tooltip: 'Encerrar Sessão',
                  ),
                ]
              : null,
          elevation: 0,
          shape: const Border(
            bottom: BorderSide(color: Color(0xFF1F222E), width: 1),
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(url: WebUri(_dashboardUrl)),
              initialUserScripts: UnmodifiableListView([
                UserScript(
                  source: """
                    (function() {
                      if (window._blobProtectionInjected) return;
                      window._blobProtectionInjected = true;

                      // 1. Prevent Google Flow from revoking blob URLs immediately
                      const _origRevoke = URL.revokeObjectURL;
                      URL.revokeObjectURL = function(url) {
                        setTimeout(function() {
                          try { _origRevoke.call(URL, url); } catch(e) {}
                        }, 60000); // Keep blob alive for 60 seconds
                      };

                      // 2. Intercept click events specifically on download links/buttons
                      document.addEventListener('click', function(e) {
                        let el = e.target;
                        while (el && el !== document.body) {
                          if (el.tagName === 'A' && (el.href || el.getAttribute('download'))) {
                            const isDownloadAttr = el.hasAttribute('download');
                            const text = (el.innerText || el.getAttribute('aria-label') || '').toLowerCase();
                            const isDownloadText = text.includes('baixar') || text.includes('download');

                            if (isDownloadAttr || isDownloadText) {
                              const url = el.href;
                              const filename = el.getAttribute('download') || 'video_flow_' + Date.now() + '.mp4';
                              if (url && (url.startsWith('blob:') || url.startsWith('http'))) {
                                fetch(url).then(res => res.blob()).then(blob => {
                                  const reader = new FileReader();
                                  reader.onloadend = function() {
                                    if (window.flutter_inappwebview) {
                                      window.flutter_inappwebview.callHandler('saveBlobFile', {
                                        filename: filename,
                                        base64Data: reader.result
                                      });
                                    }
                                  };
                                  reader.readAsDataURL(blob);
                                }).catch(err => console.error('Error reading click blob:', err));
                              }
                            }
                          }
                          el = el.parentElement;
                        }
                      }, true);
                    })();
                  """,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                userAgent: 'Mozilla/5.0 (Linux; Android 14; SM-S948B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
                supportMultipleWindows: false,
                useShouldOverrideUrlLoading: false,
                allowFileAccess: true,
                allowContentAccess: true,
                useOnDownloadStart: true,
              ),
              onWebViewCreated: (controller) {
                _webViewController = controller;

                // Register JS handler for session injection
                controller.addJavaScriptHandler(
                  handlerName: 'injectSession',
                  callback: (args) async {
                    if (args.isNotEmpty && args[0] is Map) {
                      final data = Map<String, dynamic>.from(args[0]);
                      final String email = data['email'] ?? '';
                      final List<dynamic> cookies = data['cookies'] ?? [];
                      final String? userAgent = data['userAgent'];
                      final Map<String, dynamic>? proxy = data['proxy'] != null 
                          ? Map<String, dynamic>.from(data['proxy']) 
                          : null;

                      await _injectSessionAndOpenFlow(email, cookies, userAgent, proxy);
                    }
                  },
                );

                // Register JS handler for saving Blob files directly to Android Downloads & DCIM
                controller.addJavaScriptHandler(
                  handlerName: 'saveBlobFile',
                  callback: (args) async {
                    if (args.isNotEmpty && args[0] is Map) {
                      final data = Map<String, dynamic>.from(args[0]);
                      final String filename = data['filename'] ?? 'video_flow_${DateTime.now().millisecondsSinceEpoch}.mp4';
                      final String base64Data = data['base64Data'] ?? '';

                      await _saveBase64ToDownloads(filename, base64Data);
                    }
                  },
                );
              },
              onDownloadStartRequest: (controller, downloadStartRequest) async {
                final url = downloadStartRequest.url.toString();
                final filename = downloadStartRequest.suggestedFilename ?? 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

                // Inject JS to fetch blob data and send base64 to Flutter
                await controller.evaluateJavascript(source: """
                  (function() {
                    fetch('$url').then(res => res.blob()).then(blob => {
                      const reader = new FileReader();
                      reader.onloadend = function() {
                        if (window.flutter_inappwebview) {
                          window.flutter_inappwebview.callHandler('saveBlobFile', {
                            filename: '$filename',
                            base64Data: reader.result
                          });
                        }
                      };
                      reader.readAsDataURL(blob);
                    }).catch(err => {
                      console.error('onDownloadStartRequest fetch failed:', err);
                    });
                  })();
                """);
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _webLoadingProgress = progress / 100;
                  _showWebProgress = progress < 100;
                });
              },
              onReceivedError: (controller, request, error) {
                print('WebView Received Error: ${error.description}');
              },
              onReceivedHttpError: (controller, request, errorResponse) {
                print('WebView HTTP Error: ${errorResponse.statusCode}');
              },
            ),

            if (_showWebProgress)
              LinearProgressIndicator(
                value: _webLoadingProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                minHeight: 3,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBase64ToDownloads(String filename, String base64Data) async {
    final now = DateTime.now();
    final currentHash = '${filename}_${base64Data.length}';

    // Debounce: Suppress duplicate saves within 4 seconds
    if (_lastDownloadHash == currentHash && _lastDownloadTime != null && now.difference(_lastDownloadTime!).inSeconds < 4) {
      return;
    }
    _lastDownloadTime = now;
    _lastDownloadHash = currentHash;

    try {
      String base64Str = base64Data;
      if (base64Data.contains(',')) {
        base64Str = base64Data.split(',')[1];
      }

      final bytes = base64Decode(base64Str);
      
      // Save to Downloads folder
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }

      // Save to DCIM/Flow folder for Gallery visibility
      final dcimDir = Directory('/storage/emulated/0/DCIM/Flow');
      if (!await dcimDir.exists()) {
        await dcimDir.create(recursive: true);
      }

      final cleanFileName = filename.replaceAll(RegExp(r'[^\w\.\-]'), '_');
      final String extension = (cleanFileName.endsWith('.mp4') || cleanFileName.endsWith('.png') || cleanFileName.endsWith('.jpg'))
          ? ''
          : '.mp4';
      final finalFileName = '$cleanFileName$extension';

      final downloadFilePath = '${downloadsDir.path}/$finalFileName';
      final dcimFilePath = '${dcimDir.path}/$finalFileName';

      await File(downloadFilePath).writeAsBytes(bytes);
      await File(dcimFilePath).writeAsBytes(bytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Salvo na Galeria e Downloads: $finalFileName'),
            backgroundColor: Colors.greenAccent[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
      print('Media file successfully saved to: $downloadFilePath & $dcimFilePath');
    } catch (e) {
      print('Error saving blob file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro ao salvar mídia: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _injectSessionAndOpenFlow(String email, List<dynamic> cookies, String? userAgent, Map<String, dynamic>? proxy) async {
    try {
      // 1. Handle Proxy configuration per profile
      final proxyController = ProxyController.instance();
      if (proxy != null && proxy['host'] != null && proxy['port'] != null) {
        final String host = proxy['host'];
        final int port = proxy['port'];
        final String? user = proxy['username'];
        final String? pass = proxy['password'];

        String proxyUrl = '$host:$port';
        if (user != null && user.isNotEmpty && pass != null && pass.isNotEmpty) {
          proxyUrl = '$user:$pass@$host:$port';
        }

        await proxyController.setProxyOverride(
          settings: ProxySettings(
            proxyRules: [
              ProxyRule(url: proxyUrl),
            ],
          ),
        );
        print('Proxy override set: $proxyUrl');
      } else {
        await proxyController.clearProxyOverride();
        print('Proxy override cleared (direct connection).');
      }

      // 2. Wipe old cookies
      await _cookieManager.deleteAllCookies();

      // 3. Inject session cookies into WebView
      for (var cookie in cookies) {
        final String name = cookie['name'] ?? '';
        final String value = (cookie['value'] ?? '').toString();
        final String domain = cookie['domain'] ?? 'labs.google';
        final String path = cookie['path'] ?? '/';
        final bool secure = cookie['secure'] ?? true;
        final bool httpOnly = cookie['httpOnly'] ?? false;

        // Inject all cookies for both labs.google AND boxpower.store domains
        final List<String> domains = [domain, 'boxpower.store', '.boxpower.store', 'labs.google'];
        for (final targetDomain in domains) {
          final cleanDomainLoop = targetDomain.startsWith('.') ? targetDomain.substring(1) : targetDomain;
          final cookieUriLoop = WebUri('https://$cleanDomainLoop$path');
          final String? injectionDomainLoop = name.startsWith('__Host-') ? null : targetDomain;

          try {
            await _cookieManager.setCookie(
              url: cookieUriLoop,
              name: name,
              value: value,
              domain: injectionDomainLoop,
              path: path,
              isSecure: secure,
              isHttpOnly: httpOnly,
            );
          } catch (_) {}
        }
      }

      setState(() {
        _isFlowActive = true;
        _activeEmail = email;
      });

      // 4. Navigate to Google Flow
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_targetUrl)),
      );
    } catch (e) {
      print('Error injecting session: $e');
    }
  }

  Future<void> _returnToDashboard() async {
    try {
      await ProxyController.instance().clearProxyOverride();
      await _cookieManager.deleteAllCookies();
      setState(() {
        _isFlowActive = false;
        _activeEmail = '';
      });
      await _webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_dashboardUrl)),
      );
    } catch (e) {
      print('Error returning to dashboard: $e');
    }
  }
}
