import 'package:financialresume/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:intl/intl.dart';
import '../models/section.dart';
import '../services/database_service.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'section_screen.dart';
import 'package:uuid/uuid.dart';
import '../theme/colors.dart';
import '../l10n/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService dbService = DatabaseService();
  final TextEditingController _sectionNameController = TextEditingController();
  final List<Color> _sectionColors = [
    AppColors.dark,
    Color(0xFF2D3748),
    Color(0xFF4A5568),
    Color(0xFF718096),
    Color(0xFF2C5282),
    Color(0xFF2B6CB0),
  ];

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${section.name} ${AppLocalizations.of(context).createdSuccessfully}!'),
            backgroundColor: AppColors.green,
          ),
        );
      }
    }
  }

  Future<void> _renameSection(Section section) async {
    _sectionNameController.text = section.name;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context).renameSection,
          style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: _sectionNameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context).sectionName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.dark),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dark,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).save),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSection(String id, String name) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context).deleteSection,
          style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${AppLocalizations.of(context).deleteSectionConfirmation} ${AppLocalizations.of(context).thisActionCannotBeUndone}',
          style: TextStyle(color: AppColors.dark),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(color: AppColors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              await dbService.deleteSection(id);
              Navigator.pop(context);
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).sectionDeleted),
                    backgroundColor: AppColors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppLocalizations.of(context).delete),
          ),
        ],
      ),
    );
  }

  Color _getSectionColor(int index) {
    return _sectionColors[index % _sectionColors.length];
  }

  Widget _buildSectionStats(Section section) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getSectionStats(section.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 20,
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white.withAlpha(190),
                ),
              ),
            ),
          );
        }

        if (snapshot.hasData) {
          final stats = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${stats['transactionCount']} ${AppLocalizations.of(context).transactions}',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.white.withAlpha(200),
                ),
              ),
              SizedBox(height: 2),
              Text(
                '${AppLocalizations.of(context).balance}: ${NumberFormat.currency(locale: 'pt_PT', symbol: '€').format(stats['balance'])}',
                style: TextStyle(
                  fontSize: 11,
                  color: stats['balance'] >= 0 ? AppColors.green : AppColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return Text(
          '${AppLocalizations.of(context).loading}...',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.white.withAlpha(120),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getSectionStats(String sectionId) async {
    final transactions = await dbService.getAllTransactions(sectionId);
    final balance = transactions.fold<double>(
      0,
          (sum, t) => t.isCredit ? sum + t.amount : sum - t.amount,
    );

    return {
      'transactionCount': transactions.length,
      'balance': balance,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.light,
      appBar: AppBar(
        title: Text(
          'Financial Resume',
          style: TextStyle(
            color: AppColors.dark,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.white,
        iconTheme: IconThemeData(color: AppColors.dark),
      ),
      drawer: Drawer(
        child: Container(
          color: AppColors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.dark, Color(0xFF2D3748)],
                  ),
                ),
                child: DrawerHeader(
                  decoration: BoxDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.white,
                        radius: 30,
                        child: Container(
                          height: 80,
                          width: 80,
                          child: SvgPicture.asset(
                            'assets/images/app_logo.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Financial Resume',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context).menu,
                        style: TextStyle(
                          color: AppColors.white.withAlpha(200),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildDrawerItem(
                icon: Icons.home,
                title: AppLocalizations.of(context).home,
                isSelected: true,
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _buildDrawerItem(
                icon: Icons.settings,
                title: AppLocalizations.of(context).settings,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SettingsScreen()),
                  );
                },
              ),
              //Divider(color: AppColors.grey.shade300),
              /*_buildDrawerItem(
                icon: Icons.help_outline,
                title: AppLocalizations.of(context).help,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => HelpScreen()),
                  );
                },
              ),*/
              _buildDrawerItem(
                icon: Icons.info_outline,
                title: AppLocalizations.of(context).about,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => AboutScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
           Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: FutureBuilder<List<Section>>(
              future: dbService.getAllSections(),
              builder: (context, snapshot) {
                final sectionCount = snapshot.data?.length ?? 0;
                return Column(
                  children: [
                    Text(
                      AppLocalizations.of(context).yourSections,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '$sectionCount ${AppLocalizations.of(context).sectionsCreated}',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.grey,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          SizedBox(height: 24),

          Expanded(
            child: FutureBuilder<List<Section>>(
              future: dbService.getAllSections(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: AppColors.dark),
                        SizedBox(height: 16),
                        Text(
                          '${AppLocalizations.of(context).loading}...',
                          style: TextStyle(color: AppColors.grey),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: AppColors.red,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).errorLoadingSections,
                          style: TextStyle(
                            color: AppColors.dark,
                            fontSize: 18,
                          ),
                        ),
                        SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.dark,
                            foregroundColor: AppColors.white,
                          ),
                          child: Text(AppLocalizations.of(context).tryAgain),
                        ),
                      ],
                    ),
                  );
                }

                final sections = snapshot.data ?? [];

                if (sections.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          color: AppColors.grey,
                          size: 80,
                        ),
                        SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).noSectionsCreated,
                          style: TextStyle(
                            color: AppColors.dark,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context).tapPlusToCreateFirstSection,
                          style: TextStyle(color: AppColors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: EdgeInsets.all(16),
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.3,
                    ),
                    itemCount: sections.length + 1,
                    itemBuilder: (context, index) {
                      if (index == sections.length) {
                        return _buildAddSectionCard();
                      }

                      final section = sections[index];
                      return _buildSectionCard(section, index);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppColors.dark : AppColors.grey,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppColors.dark : AppColors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
      selected: isSelected,
      selectedTileColor: AppColors.grey.shade100,
    );
  }

  Widget _buildAddSectionCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.grey.shade300, width: 1),
      ),
      color: AppColors.white,
      child: InkWell(
        onTap: () {
          _sectionNameController.clear();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                AppLocalizations.of(context).newSection,
                style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold),
              ),
              content: TextField(
                controller: _sectionNameController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).sectionName,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.dark),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  hintText: AppLocalizations.of(context).sectionName,
                ),
                autofocus: true,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).cancel,
                    style: TextStyle(color: AppColors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    _addSection();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.dark,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppLocalizations.of(context).save),
                ),
              ],
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 40,
                color: AppColors.grey,
              ),
              SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).newSection,
                style: TextStyle(
                  color: AppColors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard(Section section, int index) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _getSectionColor(index),
              _getSectionColor(index).withAlpha(195),
            ],
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onLongPress: () {
              _showSectionOptions(section);
            },
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SectionScreen(section: section),
                ),
              ).then((_) => setState(() {}));
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  children: [

                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            section.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8),
                          _buildSectionStats(section),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.white.withAlpha(50),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                DateFormat('dd/MM/yy').format(section.createdAt),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: AppColors.white.withAlpha(220),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ),
          ),
        ),
      ),
    );
  }

  void _showSectionOptions(Section section) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 20),
            Text(
              section.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            SizedBox(height: 16),
            _buildOptionButton(
              title: AppLocalizations.of(context).rename,
              onTap: () {
                Navigator.pop(context);
                _renameSection(section);
              },
            ),
            _buildOptionButton(
              title: AppLocalizations.of(context).delete,
              onTap: () {
                Navigator.pop(context);
                _deleteSection(section.id, section.name);
              },
            ),
            SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(color: AppColors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String title,
    Color titleColor = AppColors.dark,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: titleColor),
      ),
      onTap: onTap,
      minLeadingWidth: 0,
    );
  }
}