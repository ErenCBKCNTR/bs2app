import 'package:flutter/widgets.dart';

class GlobalRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  static String currentRoute = '/';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route.settings.name != null) {
      currentRoute = route.settings.name!;
    } else {
      currentRoute = route.runtimeType.toString();
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null && previousRoute.settings.name != null) {
      currentRoute = previousRoute.settings.name!;
    } else if (previousRoute != null) {
      currentRoute = previousRoute.runtimeType.toString();
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null && newRoute.settings.name != null) {
      currentRoute = newRoute.settings.name!;
    } else if (newRoute != null) {
      currentRoute = newRoute.runtimeType.toString();
    }
  }
}

final globalRouteObserver = GlobalRouteObserver();
