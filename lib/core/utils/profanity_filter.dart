
class ProfanityFilter {
  static final List<String> _profanityList = [
    // Türkçe - Yaygın Küfür, Argo ve Kısaltmalar
    "amcık", "amcik", "amk", "amq", "aq", "a.q", "a.q.", "amına", "amina", "amınakoyayım", 
    "aminakoyayim", "amınakoyim", "aminakoyim", "amınoğlu", "aminoglu", "am", "çük", "yarrak", 
    "yarak", "yarram", "yaram", "sik", "sikiş", "sikik", "sikeyim", "sikiyim", "siktir", 
    "siktirgit", "sg", "s.g", "s.g.", "siktiğim", "siktigim", "sikilmiş", "sikilmis", "oç", 
    "o.ç", "o.ç.", "orospu", "orospuçocuğu", "orospucocugu", "orospuevladı", "kahpe", "kaltak", 
    "sürtük", "yosma", "fahişe", "pezevenk", "püzevenk", "gavat", "kavat", "ibne", "ipne", 
    "puşt", "pust", "piç", "pic", "göt", "got", "götveren", "gotveren", "götoğlanı", "gotoglani", 
    "göte", "yavşak", "yavsak", "dalyarak", "dalyanak", "dürzü", "durzu", "dingil", "dangalak", 
    "şerefsiz", "serefsiz", "haysiyetsiz", "karaktersiz", "kansız", "kansiz", "soysuz", 
    "zürriyetsiz", "ecdadını", "ecdadini", "cibiliyetini", "geçmişini", "gecmisini", "yedi sülaleni", 
    "ebeni", "ebeninsiki", "anasını", "anasini", "avradını", "avradini", "bacını", "bacini", 
    "veledizina", "it", "köpek", "itsoyu", "bok", "boktan", "bokyiyen", "sıç", "sic", "sıçmak", 
    "sıçtığım", "sictigim", "sidik", "meme", "amcığa", "amciga", "yarağım", "yaragim",

    // İngilizce - Yaygın Küfür, Argo, Kısaltmalar ve Varyasyonlar
    "anal", "anus", "arse", "arsehole", "ass", "asses", "assface", "asshat", "asshole", 
    "assholes", "asswipe", "b1tch", "ballbag", "balls", "ballsack", "bastard", "bastards", 
    "bellend", "bitch", "bitches", "bitching", "bitchy", "blowjob", "bollocks", "boob", 
    "boobs", "bugger", "bullshit", "bullshite", "chink", "clit", "clitoris", "cock", "cocks", 
    "cocksucker", "coon", "crap", "crappy", "cum", "cumming", "cumshot", "cunt", "cunts", 
    "damn", "dammit", "damned", "dick", "dickhead", "dicks", "dildo", "dildos", "dipshit", 
    "dong", "douche", "douchebag", "dumbass", "dyke", "fag", "faggot", "faggots", "fags", 
    "fatass", "fuck", "fucked", "fucker", "fuckers", "fuckface", "fucking", "fucktard", 
    "fuckup", "gaylord", "goddamn", "gook", "hoe", "homo", "hooker", "jackass", "jerk", 
    "jerkoff", "jizz", "kike", "knob", "knobhead", "kraut", "lmao", "lmfao", "milf", "mofo", 
    "motherfucker", "motherfucking", "muff", "n1gga", "n1gger", "nazi", "nigga", "niggas", 
    "nigger", "niggers", "nutsack", "orgasm", "pecker", "penis", "piss", "pissed", "pissing", 
    "prick", "pricks", "pussy", "queer", "retard", "retarded", "schlong", "sex", "sexy", 
    "shag", "shemale", "shit", "shite", "shitface", "shithead", "shithole", "shitting", 
    "shitty", "skank", "slut", "sluts", "slutty", "smegma", "snatch", "sonofabitch", "spic", 
    "spunk", "stfu", "suck", "sucks", "tard", "testicle", "thot", "tit", "tits", "titties", 
    "tosser", "tranny", "turd", "twat", "vagina", "wank", "wanker", "wankers", "whore", 
    "whores", "wtf"
  ];

  static String filter(String text) {
    if (text.isEmpty) return text;
    
    String filteredText = text;
    
    // Sort by length descending to match longest words first (preventing partial matches of subsets like 'am' inside 'amcık')
    final sortedList = List<String>.from(_profanityList)..sort((a, b) => b.length.compareTo(a.length));
    
    for (String word in sortedList) {
      final regExp = RegExp(
        r'\b' + RegExp.escape(word) + r'\b', // Match whole words
        caseSensitive: false,
      );
      
      filteredText = filteredText.replaceAllMapped(regExp, (match) {
        String m = match.group(0)!;
        if (m.length <= 1) return m;
        return m[0] + "*" * (m.length - 1);
      });

      // Also support common variations without word boundaries for some very common short terms if needed, 
      // but \b is safer for general use. Let's add a more aggressive filter as well.
      // We can iterate over words and check.
    }

    return filteredText;
  }
}
