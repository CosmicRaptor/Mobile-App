import 'dart:math';

import 'package:animations/animations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsec_app/models/notes_model/notes_model.dart';
import 'package:tsec_app/models/user_model/user_model.dart';
import 'package:tsec_app/new_ui/screens/notes_screen/widgets/custom_pdf_icon.dart';
import 'package:tsec_app/new_ui/screens/notes_screen/widgets/notes_modal.dart';
import 'package:tsec_app/provider/auth_provider.dart';
import 'package:tsec_app/provider/firebase_provider.dart';
import 'package:tsec_app/provider/notes_provider.dart';
import 'package:tsec_app/utils/datetime.dart';
import 'package:tsec_app/new_ui/colors.dart';

class NoteList extends ConsumerStatefulWidget {
  void Function(
      List<String> selectedFiles,
      List<String> deletedFiles,
      List<String> originalFiles,
      String? id,
      String? title,
      String? description,
      String? subject,
      String? branch,
      String? division,
      String? year) uploadNoteCallback;
  GlobalKey<FormState> formKey;
  String searchQuery;
  DateTime? startDate;
  DateTime? endDate;
  bool latest;
  List<String> subjects;
  NoteList({
    super.key,
    required this.searchQuery,
    required this.formKey,
    required this.uploadNoteCallback,
    required this.startDate,
    required this.endDate,
    required this.latest,
    required this.subjects,
  });

  @override
  ConsumerState<NoteList> createState() => _NoteListState();
}

class _NoteListState extends ConsumerState<NoteList> {
  bool _isVisible = false;

  void _toggleFilterVisibility() {
    setState(() {
      _isVisible = !_isVisible;
    });
  }

  String _getFirst5Words(String content) {
    List<String> words = content.split(' ');
    if (words.length > 5) {
      return '${words.sublist(0, 5).join(' ')}...';
    } else {
      return content;
    }
  }

  List<NotesModel> applyFilters(List<NotesModel> notes) {
    if (widget.latest) {
      notes.sort((a, b) => b.time.compareTo(a.time));
    } else {
      notes.sort((a, b) => a.time.compareTo(b.time));
    }
    // debugPrint("after date sorting ${notes.toString()}");
    List<NotesModel> filteredNotes = notes
        .where((note) =>
    (widget.startDate == null ||
        note.time.isAfter(widget.startDate!)) &&
        (widget.endDate == null || note.time.isBefore(widget.endDate!)) &&
        (note.title.contains(widget.searchQuery) ||
            note.description.contains(widget.searchQuery)))
        .toList();
    // debugPrint("after date filtering ${filteredNotes.toString()}");
    // for (String subject in widget.subjects) {
    UserModel user = ref.read(userModelProvider)!;
    if (user.isStudent) {
      filteredNotes = filteredNotes
          .where((note) => (widget.subjects.contains(note.subject)))
          .toList();
    }
    // }
    // debugPrint("final notes are ${dateFilteredNotes}");
    // debugPrint("after subject filtering ${filteredNotes.toString()}");
    return filteredNotes;
  }

  @override
  Widget build(BuildContext context) {
    List<NotesModel> allNotes = ref.watch(notesProvider);
    UserModel? user = ref.read(userModelProvider);

    // allNotes = applyFilters(allNotes);
    // debugPrint("all notes are ${allNotes}");
    // List<NotesModel> allNotes = [];

    return allNotes.length != 0
        ? SliverList(
      delegate: SliverChildBuilderDelegate(
        childCount: allNotes.length,
            (context, i) {
          List<String> attachments = allNotes[i].attachments.map((e) {
            String newString = Uri.parse(e)
                .pathSegments
                .last
                .replaceFirst("notes_attachments/", "");
            int firstSlashIndex = newString.indexOf('/');

            if (firstSlashIndex != -1) {
              newString = newString.substring(firstSlashIndex + 1);
            }
            return newString;
          }).toList();
          print(i);
          print(attachments.toString());
          print(widget.subjects.toString());
          print(allNotes[i].professorName);
          print(user?.facultyModel?.name);

          if(widget.subjects.contains(allNotes[i].subject) || user?.facultyModel?.name==allNotes[i].professorName)
            return Column(
            children: [
              SizedBox(height: 10),
              i == 0 || allNotes[i].time != allNotes[i - 1].time
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    formatDate(allNotes[i].time),
                    style: TextStyle(
                      color: Colors.grey,
                    ),
                  )
                ],
              )
                  : Container(),
              SizedBox(
                  height:
                  i == 0 || allNotes[i].time != allNotes[i - 1].time
                      ? 15
                      : 0),
              Padding(
                padding: EdgeInsets.all(8),
                child: OpenContainer(
                  transitionDuration: Duration(milliseconds: 500),
                  closedColor: Color(0xff1B1B1B),
                  closedBuilder: (context, action) {
                    return Container(
                      // margin: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: timePickerBorder, width: 1.0),
                        borderRadius: BorderRadius.circular(20),
                        color: timePickerBg,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20,),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${allNotes[i].subject}: ${allNotes[i].title}",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(color: Colors.white),
                            ),
                            const SizedBox(
                              height: 7,
                            ),
                            Text(
                              /* use can use the
                         _getFirst5Words method here if want to
                         _getFirst5Words(widget.noteContent)
                         method on line no. 40
                                              */
                              allNotes[i].description,
                              // widget.noteContent,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall!
                                  .copyWith(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Container(
                                  width:
                                  MediaQuery.of(context).size.width *
                                      .8,
                                  height: 40,
                                  child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount:
                                      min(2, attachments.length),
                                      itemBuilder: (context, ind) {
                                        return CustomPdfIcon(
                                          pdfName: attachments[ind],
                                        );
                                      }),
                                ),
                                attachments.length > 2
                                    ? Text(
                                    "+${attachments.length - 2}",
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.tertiary,
                                      fontSize: 12,
                                    )
                                )
                                    : Container()
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  openBuilder: (context, action) {
                    return NotesModal(
                      action: action,
                      note: allNotes[i],
                      formKey: widget.formKey,
                      uploadNoteCallback: (List<String> selectedFiles,
                          List<String> deletedFiles,
                          List<String> originalFiles,
                          String? id,
                          String? title,
                          String? description,
                          String? subject,
                          String? branch,
                          String? division,
                          String? year) {
                        if (widget.formKey.currentState!.validate()) {
                          widget.uploadNoteCallback(
                              selectedFiles,
                              deletedFiles,
                              originalFiles,
                              id,
                              title,
                              description,
                              subject,
                              branch,
                              division,
                              year);
                          action.call();
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
          else
            SizedBox();
        },
      ),
    )
        : SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add your image here
            Image.asset(
              'assets/images/app_bar/notes.png',
              height: 100,
            ),
            SizedBox(height: 20),
            Text(
              "No notes added yet",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge!
                  .copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );

  }
}