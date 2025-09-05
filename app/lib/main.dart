import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/auth/data/repositories/auth_repository.dart';
import 'features/notes/presentation/bloc/notes_bloc.dart';
import 'features/notes/data/repositories/notes_repository.dart';
import 'features/notes/presentation/screens/notes_list_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'core/network/dio_client.dart';
import 'core/database/app_database.dart';
import 'core/services/sync_service.dart';
import 'core/storage/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (context) => DioClient(),
        ),
        RepositoryProvider(
          create: (context) => AppDatabase(),
        ),
        RepositoryProvider(
          create: (context) => SyncService(
            database: context.read<AppDatabase>(),
          ),
        ),
        RepositoryProvider(
          create: (context) => AuthRepository(
            dioClient: context.read<DioClient>(),
          ),
        ),
        RepositoryProvider(
          create: (context) => NotesRepository(
            dioClient: context.read<DioClient>(),
            database: context.read<AppDatabase>(),
            syncService: context.read<SyncService>(),
          ),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => AuthBloc(
              authRepository: context.read<AuthRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => NotesBloc(
              notesRepository: context.read<NotesRepository>(),
            ),
          ),
        ],
        child: MaterialApp(
          title: 'SyncKit',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          debugShowCheckedModeBanner: false,
          home: const AuthWrapper(),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthSuccess || TokenStorage.hasToken) {
          return const NotesListScreen();
        }
        return const LoginScreen();
      },
    );
  }
}