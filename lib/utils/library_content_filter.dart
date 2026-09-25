import '../models/yt_library_models.dart';

/// Kurzgesagt channel + three curated TED-Ed / Crash Course Kids playlists only.
const kKurzgesagtChannelId = 'UCsXVk37bltHxD1rDPwtNM8Q';

const kBlockedKurzgesagtPlaylistIds = {
  'PLFs4vir_WsTxmlWOMqFdKRwwErRbnep0d', // Drugs
};

/// Extra playlists beyond Kurzgesagt (TED-Ed, Crash Course Kids).
const kAllowedExtraPlaylistIds = {
  'PLJicmE8fK0EiTqtnTb9Mjb4UUyMt39YVQ', // Humans vs. Viruses
  'PLhz12vamHOnagseIgy26MoPI79NXiFBwN', // Space Science: The Sun and Its Influence on Earth
  'PLJicmE8fK0EiFngx7wBddZDzxogj-shyW', // Think Like a Coder
};

/// Curated playlists shown first in the flat library (no subject tabs).
const kPriorityPlaylistIds = [
  'PLJicmE8fK0EiTqtnTb9Mjb4UUyMt39YVQ',
  'PLhz12vamHOnagseIgy26MoPI79NXiFBwN',
  'PLJicmE8fK0EiFngx7wBddZDzxogj-shyW',
];

int compareWhitelistedPlaylistsById(String aId, String aTitle, String bId, String bTitle) {
  final ai = kPriorityPlaylistIds.indexOf(aId);
  final bi = kPriorityPlaylistIds.indexOf(bId);
  if (ai != -1 || bi != -1) {
    if (ai == -1) return 1;
    if (bi == -1) return -1;
    return ai.compareTo(bi);
  }
  return aTitle.toLowerCase().compareTo(bTitle.toLowerCase());
}

/// Subjects hidden from the Digital Library UI (e.g. US-centric history).
const kHiddenYtSubjects = {'history'};

const kForeignLanguagePatterns = [
  r'\b(espa[nñ]ol|spanish lesson|learn spanish|curso de espa[nñ]ol|speak spanish)\b',
  r'\b(fran[cç]ais|french lesson|learn french|speak french|le fran[cç]ais)\b',
  r'\b(deutsch|german lesson|learn german|speak german)\b',
  r'\b(portugu[eê]s|portuguese lesson|learn portuguese|speak portuguese)\b',
  r'\b(italiano|italian lesson|learn italian|speak italian)\b',
  r'\b(mandarin|cantonese|chinese lesson|learn chinese|speak chinese)\b',
  r'\b(japanese lesson|learn japanese|speak japanese|nihongo)\b',
  r'\b(korean lesson|learn korean|speak korean|hangul)\b',
  r'\b(hindi lesson|learn hindi|speak hindi|urdu lesson|bengali lesson)\b',
  r'\b(arabic lesson|learn arabic|speak arabic)\b',
  r'\b(welsh lesson|learn welsh|cymraeg|speak welsh)\b',
  r'\b(gaelic|irish lesson|learn irish|speak irish)\b',
  r'\b(russian lesson|learn russian|speak russian)\b',
  r'\b(learn [a-z]+ language|language lesson|foreign language)\b',
  r'\b(duolingo|babel|rosetta stone)\b',
];

/// Returns true for blocked library titles/descriptions (all subjects).
bool isBlockedLibraryContent(String title, [String? description]) {
  final text = '${title.toLowerCase()} ${(description ?? '').toLowerCase()}';
  const blocked = [
    r'\bsex ed\b',
    r'\bsex education\b',
    r'\bsexual intercourse\b',
    r'\bsexuality\b',
    r'\bmasturbat',
    r'\bporn\b',
    r'\bpornography\b',
    r'\bcontracept',
    r'\bcondom\b',
    r'\bbirth control\b',
    r'\bstd\b',
    r'\bsti\b',
    r'\bsexually transmitted\b',
    r'\babortion\b',
    r'\bpuberty\b',
    r'\breproductive system\b',
    r'\bintercourse\b',
    r'\borgasm\b',
    r'\bvirginity\b',
    r'\berectile\b',
    r'\bpenis\b',
    r'\bvagina\b',
    r'\bsexual health\b',
    r'\bsexual reproduction\b',
    r'\bcivil rights\b',
    r'\bcivil liberties\b',
    r'\bselma\b',
    r'\bmontgomery bus\b',
    r'\brosa parks\b',
    r'\bjim crow\b',
    r'\bmarch on washington\b',
    r'\bvoting rights act\b',
    r'\bap us government\b',
    r'\bap®︎/college us history\b',
  ];
  for (final pattern in blocked) {
    if (RegExp(pattern).hasMatch(text)) return true;
  }
  return false;
}

/// Kurzgesagt videos blocked for drugs, sex, or religion topics.
bool isBlockedKurzgesagtSensitiveContent(String title, [String? description]) {
  final text = '${title.toLowerCase()} ${(description ?? '').toLowerCase()}';
  const blocked = [
    r'\bdrug\b',
    r'\bdrugs\b',
    r'\bmarijuana\b',
    r'\bweed\b',
    r'\bcannabis\b',
    r'\bcocaine\b',
    r'\bheroin\b',
    r'\bfentanyl\b',
    r'\blsd\b',
    r'\bpsychedelic\b',
    r'\bopioid\b',
    r'\bvaping\b',
    r'\bozempic\b',
    r'\balcohol\b',
    r'\bwar on drugs\b',
    r'\breligion\b',
    r'\bnihilism\b',
    r'\batheis',
    r'\bgod\b',
    r'\bgods\b',
    r'\bchrist\b',
    r'\bislam\b',
    r'\bbuddh',
    r'\bafterlife\b',
    r'\bsoul\b',
    r'\bpray\b',
    r'\bchurch\b',
    r'\bmosque\b',
    r'\bbible\b',
    r'\bquran\b',
    r'\bhindu\b',
    r'\bjewish\b',
    r'\bsex ed\b',
    r'\bsex education\b',
    r'\bsexual intercourse\b',
    r'\bsexuality\b',
    r'\bmasturbat',
    r'\bporn\b',
    r'\bpornography\b',
    r'\bintercourse\b',
    r'\borgasm\b',
  ];
  for (final pattern in blocked) {
    if (RegExp(pattern).hasMatch(text)) return true;
  }
  return false;
}

bool isAllowedPlaylist({
  required String playlistId,
  String? channelId,
  String? title,
}) {
  if (kAllowedExtraPlaylistIds.contains(playlistId)) return true;
  if (kBlockedKurzgesagtPlaylistIds.contains(playlistId)) return false;
  if (title != null && title.toLowerCase().trim() == 'drugs') return false;
  if (channelId == kKurzgesagtChannelId) return true;
  return false;
}

bool isBlockedPlaylistTitle(String title) {
  final t = title.toLowerCase();
  if (t.contains('ap/college us history')) return true;
  if (t.contains('college us history')) return true;
  if (t.contains('us history') && t.contains('ap')) return true;
  if (t.contains('ap us government')) return true;
  return false;
}

bool _containsNonLatinScript(String text) {
  return RegExp(r'[\u0400-\u04FF\u4E00-\u9FFF\u0600-\u06FF\u0900-\u097F\u0590-\u05FF]')
      .hasMatch(text);
}

bool _matchesAny(String text, List<String> patterns) =>
    patterns.any((p) => RegExp(p, caseSensitive: false).hasMatch(text));

/// Foreign-language instructional content (for the Foreign Languages tab).
bool isForeignLanguageContent(String title, [String? description]) {
  final text = '$title ${description ?? ''}';
  final lower = text.toLowerCase();
  // Literature-in-translation courses stay under English, not Foreign Languages.
  if (lower.contains('literature') &&
      !_matchesAny(lower, [r'\blesson\b', r'\blearn\b', r'\bspeak\b', r'\blanguage course\b'])) {
    return false;
  }
  if (_containsNonLatinScript(text)) return true;
  return _matchesAny(lower, kForeignLanguagePatterns);
}

/// English tab: hide foreign-language lessons and mis-tagged non-ELA content.
bool _isBlockedInEnglishTab(String text) {
  if (isForeignLanguageContent(text)) return true;
  return _matchesAny(text, [
    r'\bbreadboard computer\b',
    r'\bdigital electronics\b',
    r'\bnetworking tutorial\b',
    r'\berror detection\b',
    r'\belectronic circuit\b',
  ]);
}

/// Chemistry tab: hide finance, math, and other mis-tagged playlists.
bool _isBlockedInChemistryTab(String text) {
  return _matchesAny(text, [
    r'\bpersonal finance\b',
    r'\bfinance playlist\b',
    r'\bstocks and bonds\b',
    r'\bstock market\b',
    r'\binvest(ing|ment)\b',
    r'\bbudget(ing)?\b',
    r'\bcredit score\b',
    r'\bmortgage\b',
    r'\b401k\b',
    r'\bexcel tutorial\b',
    r'\bfractions?\b',
    r'\bpercentages?\b',
    r'\blinear equations?\b',
    r'\bslope playlist\b',
    r'\bnumber systems?\b',
    r'\belectronic circuits?\b',
    r'\bbreadboard\b',
    r'\b6502\b',
    r'\bnetworking tutorial\b',
    r'\bstudy tips\b',
    r'\bchannel growth\b',
    r'\binteresting questions\b',
    r'\bbuild a .* computer\b',
  ]);
}

bool isVisibleYtSubject(String subject) => !kHiddenYtSubjects.contains(subject);

List<String> filterYtSubjects(Iterable<String> subjects) {
  final list = subjects.where(isVisibleYtSubject).toSet().toList();
  list.sort((a, b) => ytSubjectLabel(a).compareTo(ytSubjectLabel(b)));
  return list;
}

bool isVisibleForSubject({
  required String subject,
  required String title,
  String? description,
  String? playlistId,
  String? channelId,
}) {
  if (!isVisibleYtSubject(subject)) return false;
  if (playlistId != null &&
      !isAllowedPlaylist(
        playlistId: playlistId,
        channelId: channelId,
        title: title,
      )) {
    return false;
  }
  if (isBlockedPlaylistTitle(title)) return false;
  if (isBlockedLibraryContent(title, description)) return false;

  final text = '$title ${description ?? ''}';
  switch (subject) {
    case 'english':
      if (_isBlockedInEnglishTab(text)) return false;
      break;
    case 'chemistry':
      if (_isBlockedInChemistryTab(text)) return false;
      break;
  }
  return true;
}

bool isVisiblePlaylist({
  required String subject,
  required String title,
  String? description,
  required String playlistId,
  String? channelId,
}) =>
    isVisibleForSubject(
      subject: subject,
      title: title,
      description: description,
      playlistId: playlistId,
      channelId: channelId,
    );

bool isVisibleVideo({
  required String title,
  String? description,
  String? subject,
  String? playlistId,
  String? channelId,
}) {
  if (playlistId != null &&
      !isAllowedPlaylist(
        playlistId: playlistId,
        channelId: channelId,
      )) {
    return false;
  }
  if (channelId == kKurzgesagtChannelId &&
      isBlockedKurzgesagtSensitiveContent(title, description)) {
    return false;
  }
  if (isBlockedLibraryContent(title, description)) return false;
  if (subject != null &&
      !isVisibleForSubject(
        subject: subject,
        title: title,
        description: description,
        playlistId: playlistId,
        channelId: channelId,
      )) {
    return false;
  }
  return true;
}
