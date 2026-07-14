import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/persona_local_store.dart';
import '../data/models/persona.dart';

/// 当前选中的人设 Id
final selectedPersonaIdProvider =
    NotifierProvider<SelectedPersonaIdNotifier, int?>(
      SelectedPersonaIdNotifier.new,
    );

class SelectedPersonaIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int? id) => state = id;
}

final personaNotifierProvider =
    AsyncNotifierProvider<PersonaNotifier, List<Persona>>(PersonaNotifier.new);

class PersonaNotifier extends AsyncNotifier<List<Persona>> {
  @override
  Future<List<Persona>> build() => PersonaLocalStore.loadAll();

  Future<void> addPersona({
    required String name,
    required String description,
    required String systemPrompt,
    List<String> tags = const [],
  }) async {
    await PersonaLocalStore.add(
      name: name,
      description: description,
      systemPrompt: systemPrompt,
      tags: tags,
    );
    state = AsyncData(await PersonaLocalStore.loadAll());
  }

  Future<void> deletePersona(int id) async {
    await PersonaLocalStore.delete(id);
    state = AsyncData(await PersonaLocalStore.loadAll());
  }
}
