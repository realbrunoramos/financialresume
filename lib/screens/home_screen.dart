import 'package:financialresume/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/section.dart';
import '../services/database_service.dart';
import 'section_screen.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService dbService = DatabaseService();
  final TextEditingController _sectionNameController = TextEditingController();

  Future<void> _addSection() async {
    if (_sectionNameController.text.isNotEmpty) {
      final section = Section(
        id: Uuid().v4(),
        name: _sectionNameController.text,
        createdAt: DateTime.now(),
      );
      await dbService.addSection(section);
      _sectionNameController.clear();
      setState(() {});
    }
  }

  Future<void> _renameSection(Section section) async {
    _sectionNameController.text = section.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Renomear Seção'),
        content: TextField(
          controller: _sectionNameController,
          decoration: InputDecoration(
            labelText: 'Nome da Seção',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              if (_sectionNameController.text.isNotEmpty) {
                final updatedSection = Section(
                  id: section.id,
                  name: _sectionNameController.text,
                  createdAt: section.createdAt,
                );
                await dbService.updateSection(updatedSection);
                Navigator.pop(context);
                setState(() {});
              }
            },
            child: Text('Salvar'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSection(String id) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Excluir Seção'),
        content: Text('Deseja excluir esta seção e todas as suas transações?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              await dbService.deleteSection(id);
              Navigator.pop(context);
              setState(() {});
            },
            child: Text('Excluir', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text('Financial Resume'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.white,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: AppColors.dark),
              child: Text(
                'Menu',
                style: TextStyle(color: AppColors.white, fontSize: 24),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home),
              title: Text('Início'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => HomeScreen(),
                  ),
                ).then((_) => setState(() {}));
              },
              selectedTileColor: AppColors.grey.shade200,
              selectedColor: AppColors.dark,
              selected: true,
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text('Configurações'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Sair'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SizedBox(height: 50),
          Expanded(
            child: FutureBuilder<List<Section>>(
              future: dbService.getAllSections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                final sections = snapshot.data ?? [];
                return GridView.builder(
                  padding: EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.6,
                  ),
                  itemCount: sections.length + 1,
                  itemBuilder: (context, index) {
                    if (index == sections.length) {
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        color: AppColors.dark,
                        child: InkWell(
                          onTap: () {
                            _sectionNameController.clear();
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text('Nova Seção'),
                                content: TextField(
                                  controller: _sectionNameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nome da Seção',
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text('Cancelar'),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _addSection();
                                      Navigator.pop(context);
                                    },
                                    child: Text('Adicionar'),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Center(
                            child: Icon(
                              Icons.add_circle_outline,
                              size: 40,
                              color: AppColors.grey,
                            ),
                          ),
                        ),
                      );
                    }

                    final section = sections[index];
                    return Card(
                      elevation: 6,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: AppColors.dark,
                      child: InkWell(
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: AppColors.white,
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('O que pretende fazer?'),
                                    SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _renameSection(section);
                                          },
                                          child: Text('Renomear'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _deleteSection(section.id);
                                          },
                                          child: Text('Eliminar', style: TextStyle(color: AppColors.red)),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: Text('Cancelar'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SectionScreen(section: section),
                            ),
                          ).then((_) => setState(() {}));
                        },
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                                maxLines: 5,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Criado em: ${DateFormat('dd/MM/yyyy').format(section.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.grey,
                                ),
                              ),
                              Spacer(),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}