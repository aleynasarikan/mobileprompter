import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cueline/providers/script_provider.dart';
import 'package:cueline/services/script_service.dart';
import 'package:cueline/ui/theme/cueline_tokens.dart';

class OpenFileScreen extends ConsumerWidget {
  const OpenFileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scriptService = ref.watch(scriptServiceProvider.notifier);
    final theme = Theme.of(context);
    final tokens = CueLineTheme.of(context);

    return StreamBuilder(
      stream: ref.watch(scriptServiceProvider.notifier).getScripts(),
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(
          title: Text(context.tr("OpenFileScreen.title")),
          actions: [
            TextButton(
              key: const Key("OpenFileScreen.ElevatedButton_Select"),
              onPressed: () async {
                final result = await FilePicker.pickFile(
                  type: FileType.custom,
                  allowedExtensions: ['txt', 'md'],
                );
                if (result != null) {
                  final fileContent = await File(result.path!).readAsString();

                  final newScriptId = await scriptService.saveAsNew(
                    ScriptState(
                      id: null,
                      text: fileContent,
                      title: result.name,
                      isSaved: true,
                      scrollPosition: null,
                      ephemeral: false,
                    ),
                  );
                  final newScript = await scriptService.loadScript(
                    newScriptId,
                  );
                  ref.read(scriptProvider.notifier).loadScript(newScript);

                  if (!context.mounted) return;
                  context.pop();
                }
              },
              child: Text(context.tr("OpenFileScreen.ElevatedButton_Select")),
            ),
          ],
        ),
        body: (snapshot.data == null || snapshot.data!.isEmpty)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(CueLineTokens.spaceXl),
                  child: Text(
                    context.tr("OpenFileScreen.if_empty"),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: tokens.mutedText,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.only(bottom: CueLineTokens.spaceXxl),
                itemCount: snapshot.data?.length ?? 0,
                separatorBuilder: (_, _) => Divider(
                  height: 1,
                  color: tokens.hairline,
                  indent: CueLineTokens.spaceLg,
                ),
                itemBuilder: (itemContext, index) {
                  final script = snapshot.data![index];
                  return ListTile(
                    title: Text(
                      script.title,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      DateFormat.yMd().add_jm().format(
                        script.createdAt.toLocal(),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      final loadedScript = await scriptService.loadScript(
                        script.id,
                      );

                      ref
                          .read(scriptProvider.notifier)
                          .loadScript(loadedScript);

                      if (!context.mounted) return;
                      context.pop();
                    },
                    trailing: IconButton(
                      tooltip: context.tr("OpenFileScreen.ListTile_Delete"),
                      onPressed: () {
                        scriptService.deleteScript(script.id);
                      },
                      icon: const Icon(Icons.delete_outline),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
