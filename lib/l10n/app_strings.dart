class AppStrings {
  const AppStrings(this.localeCode);

  final String localeCode;

  bool get isSwahili => localeCode == 'sw';

  String get appName => 'SafeRoute';
  String get createAccount => isSwahili ? 'Fungua akaunti' : 'Create your account';
  String get welcomeBack => isSwahili ? 'Karibu tena' : 'Welcome back';
  String get registerPrompt => isSwahili
      ? 'Jisajili kwa kutumia taarifa zako ili kuendelea.'
      : 'Register with your details to continue.';
  String get loginPrompt => isSwahili
      ? 'Ingia ili kuendelea na safari salama.'
      : 'Sign in to continue your safer commute.';
  String get fullName => isSwahili ? 'Jina kamili' : 'Full name';
  String get enterName => isSwahili ? 'Weka jina lako' : 'Enter your name';
  String get emailAddress => isSwahili ? 'Barua pepe' : 'Email address';
  String get email => isSwahili ? 'Barua pepe' : 'Email';
  String get enterValidEmail => isSwahili ? 'Weka barua pepe sahihi' : 'Enter a valid email';
  String get phoneNumber => isSwahili ? 'Namba ya simu' : 'Phone number';
  String get enterValidPhone => isSwahili ? 'Weka namba sahihi ya simu' : 'Enter a valid phone number';
  String get password => isSwahili ? 'Nenosiri' : 'Password';
  String get passwordMin => isSwahili
      ? 'Nenosiri liwe na angalau herufi 8'
      : 'Password must be at least 8 characters';
  String get register => isSwahili ? 'Jisajili' : 'Register';
  String get logIn => isSwahili ? 'Ingia' : 'Log in';
  String get alreadyHaveAccount => isSwahili
      ? 'Tayari una akaunti? Ingia'
      : 'Already have an account? Log in';
  String get needAccount => isSwahili ? 'Unahitaji akaunti? Jisajili' : 'Need an account? Register';
  String get or => isSwahili ? 'au' : 'or';
  String get continueGoogle => isSwahili ? 'Endelea na Google' : 'Continue with Google';
  String get continueFacebook => isSwahili ? 'Endelea na Facebook' : 'Continue with Facebook';
  String get signOut => isSwahili ? 'Toka' : 'Sign out';
  String get home => isSwahili ? 'Nyumbani' : 'Home';
  String get routes => isSwahili ? 'Njia' : 'Routes';
    String get account => isSwahili ? 'Akaunti' : 'Account';
    @Deprecated('Use account')
    String get community => account;
  String welcomeUser(String name) => isSwahili ? 'Karibu, $name' : 'Welcome, $name';
  String get planTrip => isSwahili ? 'Panga safari yako ijayo' : 'Plan your next trip';
  String get heroSubtitle => isSwahili
      ? 'Fungua ramani, chagua usafiri, hifadhi njia, na tuma tahadhari ya SOS unaposafiri.'
      : 'Open the map, pick a transport mode, save routes, and send SOS alerts when you travel.';
  String get openRouteMap => isSwahili ? 'Fungua ramani ya njia' : 'Open route map';
  String get quickActions => isSwahili ? 'Vitendo vya haraka' : 'Quick actions';
  String get selectLocation => isSwahili ? 'Chagua eneo' : 'Select location';
  String get selectLocationSubtitle => isSwahili
      ? 'Fungua ramani na uchague mwanzo na mwisho.'
      : 'Open map and pick start and destination.';
  String get chooseTransport => isSwahili ? 'Chagua usafiri' : 'Choose transport';
  String get chooseTransportSubtitle => isSwahili
      ? 'Chagua kutembea, gari, basi, au baiskeli.'
      : 'Open map and choose walking, car, bus, or bike.';
  String get trustedPeople => isSwahili ? 'Watu wa kuaminika' : 'Trusted people';
  String get trustedPeopleSubtitle => isSwahili
      ? 'Ongeza familia au watu wa kuaminika kwa ujumbe wa SOS.'
      : 'Add family or trusted contacts for SOS messages.';
  String get travelHistory => isSwahili ? 'Historia ya safari' : 'Travel history';
  String get travelHistorySubtitle => isSwahili
      ? 'Tazama njia ulizohifadhi kutoka safari zako.'
      : 'See saved routes from your previous journeys.';
  String get safetyFirst => isSwahili ? 'Usalama kwanza' : 'Safety first';
  String get safetyFirstSubtitle => isSwahili
      ? 'Ramani ya safari ina ufuatiliaji wa moja kwa moja na kitufe cha SOS kinachoweza kutuma eneo lako kwa SMS.'
      : 'The journey map includes live tracking and an SOS action that can send your location by SMS.';
  String get previousRoutes => isSwahili ? 'Njia zote zilizopita' : 'All previous routes';
  String get previousRoutesSubtitle => isSwahili
      ? 'Kila njia uliyosafiri awali, kutoka kwenye seva.'
      : 'Every route you have traveled before, pulled from the backend.';
  String get couldNotLoadRoutes => isSwahili ? 'Imeshindikana kupakia njia' : 'Could not load routes';
  String get noSavedRoutes => isSwahili ? 'Hakuna njia zilizohifadhiwa bado' : 'No saved routes yet';
  String get noSavedRoutesSubtitle => isSwahili
      ? 'Ukimaliza safari, itaonekana hapa moja kwa moja.'
      : 'When you finish a trip, it will appear here automatically.';
  String get distance => isSwahili ? 'Umbali' : 'Distance';
  String get duration => isSwahili ? 'Muda' : 'Duration';
  String get saved => isSwahili ? 'Imehifadhiwa' : 'Saved';
  String points(int count) => isSwahili ? 'alama $count' : '$count points';
  String get accountProfile => isSwahili ? 'Wasifu wa akaunti' : 'Account profile';
  String get accountProfileSubtitle => isSwahili
      ? 'Hariri jina, barua pepe, simu, na maelezo mafupi.'
      : 'Edit your name, email, phone, and a short bio.';
  String get bioNotes => isSwahili ? 'Wasifu / maelezo ya usalama' : 'Bio / safety notes';
  String get reset => isSwahili ? 'Rudisha' : 'Reset';
  String get saveProfile => isSwahili ? 'Hifadhi wasifu' : 'Save profile';
  String get profileSaved => isSwahili ? 'Wasifu umehifadhiwa' : 'Profile saved';
  String get appSettings => isSwahili ? 'Mipangilio ya programu' : 'App settings';
  String get appSettingsSubtitle => isSwahili
      ? 'Badili lugha, mwonekano wa mandhari, au toka kwenye akaunti.'
      : 'Switch language, theme mode, or sign out of your account.';
  String get english => isSwahili ? 'Kiingereza' : 'English';
  String get swahili => isSwahili ? 'Kiswahili' : 'Swahili';
    String get toggleLanguage => isSwahili ? 'Badili lugha' : 'Toggle language';
    String get useEnglish => isSwahili ? 'Weka Kiingereza' : 'Switch to English';
    String get useSwahili => isSwahili ? 'Weka Kiswahili' : 'Switch to Swahili';
    String get themeMode => isSwahili ? 'Mandhari' : 'Theme mode';
    String get systemTheme => isSwahili ? 'Mandhari ya kifaa' : 'Device theme';
    String get lightTheme => isSwahili ? 'Mandhari nyeupe' : 'Light theme';
    String get darkTheme => isSwahili ? 'Mandhari nyeusi' : 'Dark theme';
    String get cycleThemeMode => isSwahili ? 'Badili mandhari' : 'Change theme';
  String get noTrustedPeople => isSwahili
      ? 'Hakuna watu wa kuaminika walioongezwa bado.'
      : 'No trusted people added yet.';
  String get addTrustedPerson => isSwahili ? 'Ongeza mtu wa kuaminika' : 'Add trusted person';
  String get addTrustedContact => isSwahili ? 'Ongeza mtu wa kuaminika' : 'Add trusted contact';
  String get editTrustedContact => isSwahili ? 'Hariri mtu wa kuaminika' : 'Edit trusted contact';
  String get name => isSwahili ? 'Jina' : 'Name';
  String get relationship => isSwahili ? 'Uhusiano' : 'Relationship';
  String get notes => isSwahili ? 'Maelezo' : 'Notes';
  String get cancel => isSwahili ? 'Ghairi' : 'Cancel';
  String get save => isSwahili ? 'Hifadhi' : 'Save';
  String get namePhoneRequired => isSwahili
      ? 'Jina na simu vinahitajika'
      : 'Name and phone are required';
  String get safetyNote => isSwahili ? 'Dokezo la usalama' : 'Safety note';
  String get safetyNoteSubtitle => isSwahili
      ? 'Wakati wa safari, SOS inaweza kutuma eneo lako na ujumbe mfupi kwa watu unaowaamini.'
      : 'During a journey, the SOS action can message your trusted contacts with your live location and a short alert.';
  String get sosExplanation => isSwahili
      ? 'Kitufe cha SOS hutuma ujumbe mfupi pamoja na eneo lako kwa watu uliowachagua.'
      : 'The SOS button sends a short message and your current location to the people you selected.';
}
