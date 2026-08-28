import 'app_feature.dart';

class ModuleFieldSpec {
  final String key;
  final String label;
  final String type;
  final Map<String, String> options;
  final String? suffix;

  const ModuleFieldSpec({
    required this.key,
    required this.label,
    required this.type,
    this.options = const <String, String>{},
    this.suffix,
  });

  String format(dynamic raw, {String currency = 'IQD'}) {
    if (raw == null) return '';
    final value = raw.toString().trim();
    if (value.isEmpty) return '';

    final optionLabel = options[value];
    if (optionLabel != null) return optionLabel;

    if (key == 'price') {
      final number = double.tryParse(value);
      if (number == null) return value;
      final formatted = number == number.roundToDouble()
          ? number.toInt().toString()
          : number.toStringAsFixed(2);
      return '$formatted $currency';
    }

    if (key == 'featured') {
      return value == '1' || value.toLowerCase() == 'true' ? 'بەڵێ' : 'نەخێر';
    }

    if (type == 'date' && value.length >= 10) {
      return value.substring(0, 10);
    }

    if (type == 'datetime' && value.length >= 16) {
      return value.substring(0, 16).replaceFirst('T', ' ');
    }

    if (suffix != null && suffix!.isNotEmpty) {
      return '$value $suffix';
    }

    return value;
  }
}

class ModuleSpec {
  final String key;
  final String title;
  final String subtitle;
  final String emoji;
  final String singular;
  final List<ModuleFieldSpec> fields;
  final List<String> listFields;
  final String? primaryFilterKey;

  const ModuleSpec({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.singular,
    required this.fields,
    required this.listFields,
    this.primaryFilterKey,
  });

  ModuleFieldSpec? field(String key) {
    for (final field in fields) {
      if (field.key == key) return field;
    }
    return null;
  }

  ModuleFieldSpec? get primaryFilter =>
      primaryFilterKey == null ? null : field(primaryFilterKey!);

  List<ModuleFieldSpec> get detailFields => fields.where((field) {
        return !const <String>{
          'title',
          'summary',
          'description',
          'images',
          'status',
          'priority',
          'featured',
        }.contains(field.key);
      }).toList();
}

class ModuleRegistry {
  ModuleRegistry._();

  static const Map<String, ModuleSpec> specs = <String, ModuleSpec>{

    'local_alerts': ModuleSpec(
      key: 'local_alerts',
      title: 'ئاگادارکردنەوەی ناوچەیی',
      subtitle: 'ئاگادارییە گرنگەکانی شار و ناوچە',
      emoji: '📢',
      singular: 'ئاگاداری',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناونیشانی ئاگاداری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'alert_type',
          label: 'جۆری ئاگاداری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'severity',
          label: 'ئاستی گرنگی',
          type: 'select',
          options: const <String, String>{'info': 'زانیاری', 'warning': 'ئاگاداری', 'critical': 'گرنگ / پەلەدار'},
        ),
        ModuleFieldSpec(
          key: 'summary',
          label: 'کورتە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'دەقی تەواو',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'کۆتایی ئاگاداری',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['alert_type', 'severity', 'expires_at'],
      primaryFilterKey: 'severity',
    ),
    'rentals': ModuleSpec(
      key: 'rentals',
      title: 'بازاڕی کرێ',
      subtitle: 'ماڵ، دوکان، ئۆفیس و کەرەستەی کرێ',
      emoji: '🔑',
      singular: 'کرێ',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناونیشانی کرێ',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'property_type',
          label: 'جۆری کرێ',
          type: 'select',
          options: const <String, String>{'house': 'ماڵ', 'apartment': 'شوقە', 'shop': 'دووکان', 'office': 'ئۆفیس', 'land': 'زەوی', 'equipment': 'کەرەستە'},
        ),
        ModuleFieldSpec(
          key: 'rooms',
          label: 'ژمارەی ژوور',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'area_m2',
          label: 'ڕووبەر m²',
          type: 'number',
          suffix: 'm²',
        ),
        ModuleFieldSpec(
          key: 'rent_period',
          label: 'ماوەی کرێ',
          type: 'select',
          options: const <String, String>{'daily': 'ڕۆژانە', 'monthly': 'مانگانە', 'yearly': 'ساڵانە'},
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری موڵک',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی کرێ',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی خاوەن',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'بەسەرچوون / کۆتایی',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['property_type', 'rooms', 'area_m2', 'rent_period', 'price'],
      primaryFilterKey: 'property_type',
    ),
    'beauty_personal_care': ModuleSpec(
      key: 'beauty_personal_care',
      title: 'جوانکاری و چاودێری کەسی',
      subtitle: 'سالۆن و خزمەتگوزارییەکانی جوانکاری',
      emoji: '✂️',
      singular: 'خزمەتگوزاری جوانکاری',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی سالۆن / خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری خزمەتگوزاری جوانکاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'for_gender',
          label: 'بۆ',
          type: 'select',
          options: const <String, String>{'all': 'هەمووان', 'women': 'ئافرەتان', 'men': 'پیاوان'},
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی دەستپێک',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'for_gender', 'price'],
      primaryFilterKey: 'for_gender',
    ),
    'automotive_services': ModuleSpec(
      key: 'automotive_services',
      title: 'خزمەتگوزاری ئۆتۆمبێل',
      subtitle: 'میکانیک و خزمەتگوزاری ئۆتۆمبێل',
      emoji: '🔧',
      singular: 'خزمەتگوزاری ئۆتۆمبێل',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی گەراج / خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری خزمەتگوزاری ئۆتۆمبێل',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'vehicle_type',
          label: 'جۆری ئۆتۆمبێل',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی دەستپێک',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'vehicle_type', 'price'],
      primaryFilterKey: 'currency',
    ),
    'event_services': ModuleSpec(
      key: 'event_services',
      title: 'خزمەتگوزاری بۆ بۆنەکان',
      subtitle: 'هۆڵ، وێنەگر، ڕازاندنەوە و زیاتر',
      emoji: '🎉',
      singular: 'خزمەتگوزاری بۆنە',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی خزمەتگوزاری / هۆڵ',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری خزمەتگوزاری بۆنە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'capacity',
          label: 'توانای وەرگرتن / ژمارە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی خزمەتگوزاری',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'capacity', 'price'],
      primaryFilterKey: 'currency',
    ),
    'home_services': ModuleSpec(
      key: 'home_services',
      title: 'خزمەتگوزاری ماڵانە',
      subtitle: 'کارەبایی، ئاو، چاککردنەوە و زیاتر',
      emoji: '🏡',
      singular: 'خزمەتگوزاری ماڵ',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی خزمەتگوزاری / پیشەساز',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'availability',
          label: 'کاتی بەردەستبوون',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری خزمەتگوزاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی دەستپێک',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پیشەساز',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'availability', 'price'],
      primaryFilterKey: 'currency',
    ),
    'night_services': ModuleSpec(
      key: 'night_services',
      title: 'خزمەتگوزارییە شەوانەکان',
      subtitle: 'خزمەتگوزارییە کراوەکانی شەو',
      emoji: '🌙',
      singular: 'خزمەتگوزاری شەوانە',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی شوێن / خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'night_hours',
          label: 'کاتی شەوانە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی خزمەتگوزاری',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'night_hours', 'price'],
      primaryFilterKey: 'currency',
    ),
    'service_requests': ModuleSpec(
      key: 'service_requests',
      title: 'داواکاری خزمەتگوزاری',
      subtitle: 'داواکاری یارمەتی و خزمەتگوزاری ناوخۆیی',
      emoji: '🛠️',
      singular: 'داواکاری',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'چی خزمەتگوزارییەکت پێویستە؟',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'urgency',
          label: 'پەلە',
          type: 'select',
          options: const <String, String>{'normal': 'ئاسایی', 'urgent': 'پەلەدار', 'today': 'ئەمڕۆ'},
        ),
        ModuleFieldSpec(
          key: 'budget_text',
          label: 'بودجە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'summary',
          label: 'کورتەی داواکاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'تا کەی داواکارییەکە چالاک بێت',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'urgency', 'budget_text'],
      primaryFilterKey: 'urgency',
    ),
    'emergency_numbers': ModuleSpec(
      key: 'emergency_numbers',
      title: 'فریاکەوتن و ژمارە گرنگەکان',
      subtitle: 'ژمارە و ناونیشانی خزمەتگوزارییە گرنگەکان',
      emoji: '🚨',
      singular: 'ژمارەی گرنگ',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی خزمەتگوزاری / دامەزراوە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'department',
          label: 'بەش / دامەزراوە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'availability',
          label: 'کاتی بەردەستبوون',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'تێبینی',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی بەرپرسیار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'لۆگۆ / وێنە',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['department', 'availability', 'phone'],
    ),
    'education_tutors': ModuleSpec(
      key: 'education_tutors',
      title: 'فێرکاری و مامۆستا',
      subtitle: 'مامۆستا و کۆرسە ناوخۆییەکان',
      emoji: '🎓',
      singular: 'مامۆستا/کۆرس',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی مامۆستا / کۆرس',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'subject',
          label: 'بابەت / کۆرس',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'level',
          label: 'ئاست',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'delivery',
          label: 'شێوازی وانە',
          type: 'select',
          options: const <String, String>{'in_person': 'بە ئامادەبوون', 'online': 'Online', 'both': 'هەردووکی'},
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری کۆرس',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی وانە / کۆرس',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی مامۆستا',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['subject', 'level', 'delivery', 'price'],
      primaryFilterKey: 'delivery',
    ),
    'jobs': ModuleSpec(
      key: 'jobs',
      title: 'هەلی کار',
      subtitle: 'کار و هەلی دامەزراندن',
      emoji: '💼',
      singular: 'هەلی کار',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی پۆست / کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'company',
          label: 'کۆمپانیا / دامەزراوە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'job_type',
          label: 'جۆری کار',
          type: 'select',
          options: const <String, String>{'full_time': 'Full time', 'part_time': 'Part time', 'contract': 'Contract', 'temporary': 'Temporary', 'internship': 'Internship'},
        ),
        ModuleFieldSpec(
          key: 'salary_text',
          label: 'مووچە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'experience',
          label: 'ئەزموونی پێویست',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'summary',
          label: 'کورتەی کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'پێداویستی و وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی شوێنی کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی بەرپرسیار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی ناردنی CV',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'کۆتایی وەرگرتنی داواکاری',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'لۆگۆ / وێنە',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['company', 'job_type', 'salary_text', 'experience'],
      primaryFilterKey: 'job_type',
    ),
    'lost_found': ModuleSpec(
      key: 'lost_found',
      title: 'ونبوو / دۆزراوە',
      subtitle: 'شتە ونبوو و دۆزراوەکان',
      emoji: '🔎',
      singular: 'بابەتی ونبوو/دۆزراوە',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناونیشان',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'kind',
          label: 'جۆر',
          type: 'select',
          options: const <String, String>{'lost': 'ونبوو', 'found': 'دۆزراوە'},
        ),
        ModuleFieldSpec(
          key: 'item_type',
          label: 'جۆری شت',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'event_date',
          label: 'بەرواری ونبوون / دۆزینەوە',
          type: 'date',
        ),
        ModuleFieldSpec(
          key: 'reward',
          label: 'پاداشت',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'نیشانە و وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'شوێنی ونبوون / دۆزینەوە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'بەسەرچوون / کۆتایی',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['kind', 'item_type', 'event_date', 'reward'],
      primaryFilterKey: 'kind',
    ),
    'sports_fitness': ModuleSpec(
      key: 'sports_fitness',
      title: 'وەرزش و فیتنەس',
      subtitle: 'جیم، ڕاهێنەر و ناوەندی وەرزشی',
      emoji: '🏋️',
      singular: 'خزمەتگوزاری وەرزشی',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی جیم / ڕاهێنەر',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری وەرزش / خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'coach',
          label: 'ڕاهێنەر',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'working_hours',
          label: 'کاتی کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی مانگانە / خزمەتگوزاری',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_type', 'coach', 'working_hours', 'price'],
      primaryFilterKey: 'currency',
    ),
    'local_translation': ModuleSpec(
      key: 'local_translation',
      title: 'وەرگێڕان و زمان',
      subtitle: 'وەرگێڕ و خزمەتگوزاری زمانی ناوخۆیی',
      emoji: '🌐',
      singular: 'خزمەتگوزاری وەرگێڕان',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی وەرگێڕ / ئۆفیس',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'languages',
          label: 'زمانەکان',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_type',
          label: 'جۆری وەرگێڕان',
          type: 'select',
          options: const <String, String>{'written': 'نووسراو', 'oral': 'زارەکی', 'both': 'هەردووکی'},
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی خزمەتگوزاری',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی وەرگێڕ',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['languages', 'service_type', 'price'],
      primaryFilterKey: 'service_type',
    ),
    'legal_services': ModuleSpec(
      key: 'legal_services',
      title: 'پارێزەر و خزمەتگوزاری یاسایی',
      subtitle: 'پارێزەر و ئۆفیسی یاسایی ناوخۆیی',
      emoji: '⚖️',
      singular: 'خزمەتگوزاری یاسایی',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی پارێزەر / ئۆفیس',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'specialty',
          label: 'پسپۆڕی یاسایی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'license_info',
          label: 'زانیاری مۆڵەت',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'دەربارە و خزمەتگوزاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی ڕاوێژ / خزمەتگوزاری',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پارێزەر',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['specialty', 'license_info', 'price'],
      primaryFilterKey: 'currency',
    ),
    'health_directory': ModuleSpec(
      key: 'health_directory',
      title: 'پزیشک و ناوەندی تەندروستی',
      subtitle: 'دۆزینەوەی پزیشک و ناوەندی تەندروستی',
      emoji: '🩺',
      singular: 'پزیشک/ناوەند',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی پزیشک / ناوەند',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'facility_type',
          label: 'جۆر',
          type: 'select',
          options: const <String, String>{'doctor': 'پزیشک', 'clinic': 'کلینیک', 'hospital': 'نەخۆشخانە', 'lab': 'تاقیگە', 'pharmacy': 'دەرمانخانە'},
        ),
        ModuleFieldSpec(
          key: 'specialty',
          label: 'پسپۆڕی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'working_hours',
          label: 'کاتی کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'summary',
          label: 'کورتە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'زانیاری زیاتر',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی کلینیک / ناوەند',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی ناوەند / حجز',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنە / لۆگۆ',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['facility_type', 'specialty', 'working_hours', 'phone'],
      primaryFilterKey: 'facility_type',
    ),
    'freelancers': ModuleSpec(
      key: 'freelancers',
      title: 'پیشەسازانی سەربەخۆ',
      subtitle: 'Freelancer و خزمەتگوزاری دیجیتاڵی',
      emoji: '💻',
      singular: 'فریلانسر',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی فریلانسر / براند',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'skill',
          label: 'توانا / Skill',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'experience',
          label: 'ئەزموون',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'portfolio_url',
          label: 'Portfolio URL',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'دەربارە و خزمەتگوزاری',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی دەستپێک',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی فریلانسر',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکان',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['skill', 'experience', 'price'],
      primaryFilterKey: 'currency',
    ),
    'government_hours': ModuleSpec(
      key: 'government_hours',
      title: 'کاتەکانی خزمەتگوزاری حکومی',
      subtitle: 'کات و شوێنی دامەزراوە فەرمییەکان',
      emoji: '🏛️',
      singular: 'خزمەتگوزاری حکومی',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی فەرمانگە / دامەزراوە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'department',
          label: 'دامەزراوە / فەرمانگە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'service_name',
          label: 'خزمەتگوزاری',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'working_hours',
          label: 'کاتی کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'زانیاری زیاتر',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی فەرمی',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'لۆگۆ / وێنە',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['service_name', 'working_hours', 'department'],
    ),
    'cars_market': ModuleSpec(
      key: 'cars_market',
      title: 'کڕین و فرۆشتنی ئۆتۆمبێل',
      subtitle: 'ئۆتۆمبێلی بەکارهاتوو و فرۆشتن',
      emoji: '🚗',
      singular: 'ئۆتۆمبێل',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناونیشانی ئۆتۆمبێل',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'make',
          label: 'مارکە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'model',
          label: 'مۆدێل',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'year',
          label: 'ساڵ',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'mileage',
          label: 'کیلۆمەتر',
          type: 'number',
          suffix: 'km',
        ),
        ModuleFieldSpec(
          key: 'transmission',
          label: 'گێڕ',
          type: 'select',
          options: const <String, String>{'automatic': 'Automatic', 'manual': 'Manual'},
        ),
        ModuleFieldSpec(
          key: 'fuel',
          label: 'سوتەمەنی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری ئۆتۆمبێل',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی فرۆشتن',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی خاوەن',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'ماوەی ڕیکلام',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکانی ئۆتۆمبێل',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['make', 'model', 'year', 'mileage', 'transmission', 'price'],
      primaryFilterKey: 'transmission',
    ),
    'real_estate_market': ModuleSpec(
      key: 'real_estate_market',
      title: 'کڕین و فرۆشتنی خانووبەرە',
      subtitle: 'ماڵ، زەوی، دوکان و ئۆفیس بۆ فرۆشتن',
      emoji: '🏠',
      singular: 'موڵک',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناونیشانی موڵک',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'property_type',
          label: 'جۆری موڵک',
          type: 'select',
          options: const <String, String>{'house': 'ماڵ', 'apartment': 'شوقە', 'land': 'زەوی', 'shop': 'دووکان', 'office': 'ئۆفیس', 'building': 'بینای بازرگانی'},
        ),
        ModuleFieldSpec(
          key: 'rooms',
          label: 'ژمارەی ژوور',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'area_m2',
          label: 'ڕووبەر m²',
          type: 'number',
          suffix: 'm²',
        ),
        ModuleFieldSpec(
          key: 'deed_type',
          label: 'جۆری تاپۆ / بەڵگە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'وردەکاری موڵک',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'price',
          label: 'نرخی فرۆشتن',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'currency',
          label: 'دراو',
          type: 'select',
          options: const <String, String>{'IQD': 'IQD', 'USD': 'USD'},
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی خاوەن / نووسینگە',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'expires_at',
          label: 'ماوەی ڕیکلام',
          type: 'datetime',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'وێنەکانی موڵک',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['property_type', 'rooms', 'area_m2', 'deed_type', 'price'],
      primaryFilterKey: 'property_type',
    ),
    'companies_professionals': ModuleSpec(
      key: 'companies_professionals',
      title: 'کۆمپانیا و پیشەساز',
      subtitle: 'کۆمپانیا، ئۆفیس و پیشەسازانی ناوخۆ',
      emoji: '🏢',
      singular: 'کۆمپانیا/پیشەساز',
      fields: <ModuleFieldSpec>[
        ModuleFieldSpec(
          key: 'title',
          label: 'ناوی پیشەساز / کۆمپانیا',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'profession',
          label: 'پیشە / بواری کار',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'company_name',
          label: 'ناوی کۆمپانیا',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'website',
          label: 'Website',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'description',
          label: 'دەربارە',
          type: 'textarea',
        ),
        ModuleFieldSpec(
          key: 'city_id',
          label: 'شار',
          type: 'city',
        ),
        ModuleFieldSpec(
          key: 'region_id',
          label: 'ناوچە',
          type: 'region',
        ),
        ModuleFieldSpec(
          key: 'address_detail',
          label: 'ناونیشانی ورد',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'contact_name',
          label: 'ناوی پەیوەندی',
          type: 'text',
        ),
        ModuleFieldSpec(
          key: 'phone',
          label: 'ژمارەی مۆبایل',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'whatsapp',
          label: 'WhatsApp',
          type: 'tel',
        ),
        ModuleFieldSpec(
          key: 'external_url',
          label: 'لینکی زیاتر',
          type: 'url',
        ),
        ModuleFieldSpec(
          key: 'images',
          label: 'لۆگۆ / وێنە',
          type: 'images',
        ),
        ModuleFieldSpec(
          key: 'status',
          label: 'دۆخ',
          type: 'select',
          options: const <String, String>{'approved': 'پەسەندکراو', 'pending': 'چاوەڕوان', 'hidden': 'شاراوە', 'closed': 'داخراو', 'rejected': 'ڕەتکراو'},
        ),
        ModuleFieldSpec(
          key: 'priority',
          label: 'ڕیزبەندی',
          type: 'number',
        ),
        ModuleFieldSpec(
          key: 'featured',
          label: 'لە پێشەوە نیشان بدرێت',
          type: 'checkbox',
        ),
      ],
      listFields: <String>['profession', 'company_name', 'website'],
    ),
  };

  static List<ModuleSpec> get all => specs.values.toList(growable: false);

  static ModuleSpec? byKey(String key) => specs[key];

  static bool contains(String key) => specs.containsKey(key);

  /// Build the visible module from the database feature row. Known modules
  /// keep their rich per-module field definitions while title/subtitle/sort
  /// remain server controlled. New module keys are still visible without
  /// adding them to this registry; their endpoint is /api/modules/<key>.php.
  static ModuleSpec fromFeature(AppFeature feature) {
    final known = byKey(feature.key);
    if (known != null) {
      return ModuleSpec(
        key: known.key,
        title: feature.title.isNotEmpty ? feature.title : known.title,
        subtitle:
            feature.subtitle.isNotEmpty ? feature.subtitle : known.subtitle,
        emoji: known.emoji,
        singular: known.singular,
        fields: known.fields,
        listFields: known.listFields,
        primaryFilterKey: known.primaryFilterKey,
      );
    }

    return ModuleSpec(
      key: feature.key,
      title: feature.title.isNotEmpty ? feature.title : feature.key,
      subtitle: feature.subtitle,
      emoji: _featureEmoji(feature.icon),
      singular: feature.title.isNotEmpty ? feature.title : 'خزمەتگوزاری',
      fields: const <ModuleFieldSpec>[
        ModuleFieldSpec(key: 'title', label: 'ناونیشان', type: 'text'),
        ModuleFieldSpec(key: 'summary', label: 'کورتە', type: 'text'),
        ModuleFieldSpec(key: 'description', label: 'وردەکاری', type: 'textarea'),
        ModuleFieldSpec(key: 'city_id', label: 'شار', type: 'city'),
        ModuleFieldSpec(key: 'region_id', label: 'ناوچە', type: 'region'),
        ModuleFieldSpec(key: 'address_detail', label: 'ناونیشانی ورد', type: 'text'),
        ModuleFieldSpec(key: 'contact_name', label: 'ناوی پەیوەندی', type: 'text'),
        ModuleFieldSpec(key: 'phone', label: 'مۆبایل', type: 'tel'),
        ModuleFieldSpec(key: 'whatsapp', label: 'WhatsApp', type: 'tel'),
        ModuleFieldSpec(key: 'price', label: 'نرخ', type: 'number'),
        ModuleFieldSpec(key: 'currency', label: 'دراو', type: 'text'),
        ModuleFieldSpec(key: 'external_url', label: 'لینک', type: 'url'),
        ModuleFieldSpec(key: 'images', label: 'وێنەکان', type: 'images'),
      ],
      listFields: const <String>['price', 'contact_name'],
    );
  }

  static String _featureEmoji(String rawIcon) {
    final icon = rawIcon.trim();
    if (icon.isEmpty) return '🧩';
    if (icon.runes.any((rune) => rune > 0x7F)) return icon;

    switch (icon.toLowerCase()) {
      case 'work':
      case 'jobs':
        return '💼';
      case 'home':
      case 'house':
        return '🏠';
      case 'car':
      case 'directions_car':
        return '🚗';
      case 'health':
      case 'medical_services':
        return '🩺';
      case 'school':
      case 'education':
        return '🎓';
      case 'legal':
      case 'gavel':
        return '⚖️';
      case 'fitness':
      case 'sports':
        return '🏃';
      case 'translate':
        return '🌐';
      case 'warning':
      case 'notifications':
        return '📢';
      default:
        return '🧩';
    }
  }
}
