import 'package:moor/moor.dart';
import 'package:moor_flutter/moor_flutter.dart';

// Moor works by source gen. This file will all the generated code.
part 'moor_database.g.dart';

// The name of the database table is "tasks"
// By default, the name of the generated data class will be "Task" (without "s")
class Tasks extends Table {
  // autoIncrement automatically sets this to be the primary key
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tagName =>
      text().nullable().customConstraint('NULL REFERENCES tags(name)')();
  // If the length constraint is not fulfilled, the Task will not
  // be inserted into the database and an exception will be thrown.
  TextColumn get name => text().withLength(min: 1, max: 50)();
  // DateTime is not natively supported by SQLite
  // Moor converts it to & from UNIX seconds
  DateTimeColumn get dueDate => dateTime().nullable()();
  // Booleans are not supported as well, Moor converts them to integers
  // Simple default values are specified as Constants
  BoolColumn get completed => boolean().withDefault(Constant(false))();

  // Custom primary keys defined as a set of columns
  // @override
  // Set<Column> get primaryKey => {id, name};
}

class Tags extends Table {
  TextColumn get name => text().withLength(min: 1, max: 10)();
  IntColumn get color => integer()();

  // Making name as the primary key of a tag requires names to be unique
  @override
  Set<Column> get primaryKey => {name};
}

// We have to group tasks with tags manually.
// This class will be used for the table join.
class TaskWithTag {
  final Task task;
  final Tag tag;

  TaskWithTag({
    @required this.task,
    @required this.tag,
  });
}

@UseMoor(
  tables: [Tasks, Tags],
  daos: [TaskDao, TagDao],
  // queries: {
  //   // An implementation of this query will be generated inside the _$TaskDaoMixin
  //   // Both completeTasksGenerated() and watchCompletedTasksGenerated() will be created.
  //   'completedTasksGenerated':
  //       'SELECT * FROM tasks WHERE completed = 1 ORDER BY due_date DESC, name;'
  // },
)
// _$AppDatabase is the name of the generated class
class AppDatabase extends _$AppDatabase {
  AppDatabase()
      // Specify the location of the database file
      : super((FlutterQueryExecutor.inDatabaseFolder(
          path: 'db.sqlite',
          // Good for debugging - prints SQL in the console
          logStatements: true,
        )));

  // Bump this when changing tables and columns.
  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // Runs if the database has already been opened on the device with a lower version
        onUpgrade: (migrator, from, to) async {
          if (from == 1) {
            await migrator.addColumn(tasks, tasks.tagName);
            await migrator.createTable(tags);
          }
        },
        // Runs after all the migrations but BEFORE any queries have a chance to execute
        beforeOpen: (db, details) async {
          await db.customStatement('PRAGMA foreign_keys = ON');
        },
      );
}

// Denote which tables this DAO can access
// Also accessing the Tags table for the join
@UseDao(
  tables: [Tasks, Tags],
)
class TaskDao extends DatabaseAccessor<AppDatabase> with _$TaskDaoMixin {
  final AppDatabase db;

  // Called by the AppDatabase class
  TaskDao(this.db) : super(db);

// Return TaskWithTag now
  Stream<List<TaskWithTag>> watchAllTasks() {
    // Wrap the whole select statement in parenthesis
    return (select(tasks)
          // Statements like orderBy and where return void => the need to use a cascading ".." operator
          ..orderBy(
            ([
              // Primary sorting by due date
              (t) =>
                  OrderingTerm(expression: t.dueDate, mode: OrderingMode.asc),
              // Secondary alphabetical sorting
              (t) => OrderingTerm(expression: t.name),
            ]),
          ))
        // As opposed to orderBy or where, join returns a value. This is what we want to watch/get.
        .join(
          [
            // Join all the tasks with their tags.
            // It's important that we use equalsExp and not just equals.
            // This way, we can join using all tag names in the tasks table, not just a specific one.
            leftOuterJoin(tags, tags.name.equalsExp(tasks.tagName)),
          ],
        )
        // watch the whole select statement including the join
        .watch()
        // Watching a join gets us a Stream of List<TypedResult>
        // Mapping each List<TypedResult> emitted by the Stream to a List<TaskWithTag>
        .map(
          (rows) => rows.map(
            (row) {
              return TaskWithTag(
                task: row.readTable(tasks),
                tag: row.readTable(tags),
              );
            },
          ).toList(),
        );
  }

  // Stream<List<Task>> watchCompletedTasks() {
  //   // where returns void, need to use the cascading operator
  //   return (select(tasks)
  //         ..orderBy(
  //           ([
  //             // Primary sorting by due date
  //             (t) =>
  //                 OrderingTerm(expression: t.dueDate, mode: OrderingMode.desc),
  //             // Secondary alphabetical sorting
  //             (t) => OrderingTerm(expression: t.name),
  //           ]),
  //         )
  //         ..where((t) => t.completed.equals(true)))
  //       .watch();
  // }

  // // Watching complete tasks with a custom query
  // Stream<List<Task>> watchCompletedTasksCustom() {
  //   return customSelectStream(
  //     'SELECT * FROM tasks WHERE completed = 1 ORDER BY due_date DESC, name;',
  //     // The Stream will emit new values when the data inside the Tasks table changes
  //     readsFrom: {tasks},
  //   )
  //       // customSelect or customSelectStream gives us QueryRow list
  //       // This runs each time the Stream emits a new value.
  //       .map((rows) {
  //     // Turning the data of a row into a Task object
  //     return rows.map((row) => Task.fromData(row.data, db)).toList();
  //   });
  // }

  Future insertTask(Insertable<Task> task) => into(tasks).insert(task);
  // Updates a Task with a matching primary key
  Future updateTask(Insertable<Task> task) => update(tasks).replace(task);
  Future deleteTask(Insertable<Task> task) => delete(tasks).delete(task);
}

@UseDao(tables: [Tags])
class TagDao extends DatabaseAccessor<AppDatabase> with _$TagDaoMixin {
  final AppDatabase db;

  TagDao(this.db) : super(db);

  Stream<List<Tag>> watchTags() => select(tags).watch();
  Future insertTag(Insertable<Tag> tag) => into(tags).insert(tag);
}
