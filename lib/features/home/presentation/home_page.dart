import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gena/core/di/service_locator.dart';
import 'package:gena/features/home/presentation/cubit/home_cubit.dart';
import 'package:gena/features/home/presentation/widgets/home_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(value: sl<HomeCubit>(), child: const HomeView());
  }
}
