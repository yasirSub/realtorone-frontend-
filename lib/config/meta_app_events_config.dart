/// Meta App Events identifiers for RealtorOne.
///
/// The mobile SDK sends events to the Meta app (App ID). Link that app to
/// dataset [datasetId] in Events Manager so campaign events appear there.
///
/// Client token: Meta Developer Console → App → Settings → Advanced → Client Token.
/// Set the same value in [clientToken] and in native config
/// (`android/.../strings.xml`, `ios/Runner/Info.plist`).
class MetaAppEventsConfig {
  MetaAppEventsConfig._();

  static const appId = '941459318855673';
  static const datasetId = '875528495030082';
  static const displayName = 'RealtorOne';

  /// Required by Meta SDK v13+. Replace before shipping to production.
  static const clientToken = 'REPLACE_WITH_META_CLIENT_TOKEN';
}
