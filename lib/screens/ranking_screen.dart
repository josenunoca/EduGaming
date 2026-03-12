import 'package:flutter/material.dart';

class RankingScreen extends StatelessWidget {
  final String subjectId;
  final String subjectName;
  final bool isTeacher;

  const RankingScreen({
    super.key, 
    required this.subjectId, 
    required this.subjectName,
    this.isTeacher = false,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Rankings - $subjectName'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Disciplina'),
              Tab(text: 'Todos os Tempos'),
            ],
            indicatorColor: Color(0xFF00D1FF),
          ),
        ),
        body: TabBarView(
          children: [
            _RankingList(
              type: 'subject', 
              subjectId: subjectId, 
              canDelete: isTeacher,
            ),
            const _RankingList(
              type: 'allTime', 
              canDelete: false, // Never deletable
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingList extends StatelessWidget {
  final String type;
  final String? subjectId;
  final bool canDelete;

  const _RankingList({required this.type, this.subjectId, required this.canDelete});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 10, // Mock data
      itemBuilder: (context, index) {
        return Card(
          color: Colors.white.withValues(alpha: 0.05),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: index < 3 ? const Color(0xFFFFD700).withValues(alpha: 0.8) : Colors.white10,
              child: Text('${index + 1}', style: const TextStyle(color: Colors.white)),
            ),
            title: Text('Aluno Exemplo ${index + 1}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${(100 - (index * 5))} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF00D1FF))),
                if (canDelete) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    onPressed: () {
                      // Logic to delete specific ranking record or entire list
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
