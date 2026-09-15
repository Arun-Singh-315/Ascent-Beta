part of '../app_database.dart';

@DriftAccessor(tables: [InterviewPrepTable])
class InterviewPrepDao extends DatabaseAccessor<AppDatabase>
    with _$InterviewPrepDaoMixin {
  InterviewPrepDao(super.db);

  /// Stream of all interview prep questions, newest first.
  Stream<List<InterviewPrep>> watchAllQuestions() => (select(interviewPrepTable)
        ..orderBy([(q) => OrderingTerm.desc(q.preparedAt)]))
      .watch();

  /// Stream of questions linked to a specific pipeline application.
  Stream<List<InterviewPrep>> watchQuestionsForApplication(
    int applicationId,
  ) =>
      (select(interviewPrepTable)
            ..where((q) => q.linkedApplicationId.equals(applicationId))
            ..orderBy([(q) => OrderingTerm.desc(q.preparedAt)]))
          .watch();

  /// Search questions by keyword (question, company, or category).
  Stream<List<InterviewPrep>> searchQuestions(String query) {
    final lower = '%$query%';
    return (select(interviewPrepTable)
          ..where(
            (q) =>
                q.questionAsked.like(lower) |
                q.company.like(lower) |
                q.category.like(lower),
          )
          ..orderBy([(q) => OrderingTerm.desc(q.preparedAt)]))
        .watch();
  }

  /// Insert a question.
  Future<int> insertQuestion(InterviewPrepTableCompanion companion) =>
      into(interviewPrepTable).insert(companion);

  /// Update a question.
  Future<bool> updateQuestion(InterviewPrepTableCompanion companion) async {
    final rowsAffected = await (update(interviewPrepTable)
          ..where((q) => q.id.equals(companion.id.value)))
        .write(companion);
    return rowsAffected == 1;
  }

  /// Delete a question.
  Future<int> deleteQuestion(int id) =>
      (delete(interviewPrepTable)..where((q) => q.id.equals(id))).go();
}
