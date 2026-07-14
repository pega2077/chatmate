class Persona {
  final int id;
  final String name; // 人设名称，如“职场太极大师”
  final String description; // 用户可见的人设描述
  final String systemPrompt; // 核心 Prompt 约束
  final List<String> tags; // 标签，如 ['Work', 'Humor']
  final DateTime createdAt;

  const Persona({
    required this.id,
    required this.name,
    required this.description,
    required this.systemPrompt,
    required this.tags,
    required this.createdAt,
  });

  Persona copyWith({
    int? id,
    String? name,
    String? description,
    String? systemPrompt,
    List<String>? tags,
    DateTime? createdAt,
  }) {
    return Persona(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      tags: tags ?? this.tags,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'systemPrompt': systemPrompt,
    'tags': tags,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Persona.fromJson(Map<String, dynamic> json) {
    return Persona(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      systemPrompt: json['systemPrompt'] as String? ?? '',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
