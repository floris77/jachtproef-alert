import 'package:flutter/material.dart';
import 'proeven_main_page.dart';

const Color kMainColor = Color(0xFF535B22);

class HelpScreen extends StatelessWidget {
  const HelpScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Help & Uitleg', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: kMainColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeSection(),
            const SizedBox(height: 24),
            _buildFeatureSection(
              'Proeven Pagina',
              Icons.list,
              [
                'Bekijk alle beschikbare jachtproeven',
                'Gebruik de zoekbalk om specifieke proeven te vinden',
                'Filter op type proef (Veldwedstrijd, SJP, MAP, PJP, TAP, KAP, SWT, OWT, Test)',
                                  'Sorteer op status: Alle, Inschrijven, Binnenkort, Gesloten',
                'Tik op een proef voor meer details en aanmelding',
              ],
            ),
            const SizedBox(height: 20),
            _buildNavigationSection(),
            const SizedBox(height: 20),
            _buildFeatureSection(
              'Proef Details Pagina',
              Icons.info_outline,
              [
                'Bekijk alle informatie over een specifieke proef',
                                  'Zie de status: Inschrijven, Binnenkort, of Gesloten',
                'Gebruik de actieknoppen om je interesse aan te geven',
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailButtonsSection(),
            const SizedBox(height: 20),
            _buildFeatureSection(
              'Mijn Agenda',
              Icons.calendar_today,
              [
                'Bekijk je aangemelde proeven',
                'Zie belangrijke data en tijden',
                'Voeg proeven toe aan je telefoon agenda',
                'Ontvang herinneringen voor aankomende proeven',
              ],
            ),
            const SizedBox(height: 20),
            _buildFeatureSection(
              'Instellingen',
              Icons.settings,
              [
                'Beheer je account gegevens',
                'Stel notificatie voorkeuren in',
                'Bekijk app informatie en versie',
                'Log uit wanneer nodig',
              ],
            ),
            const SizedBox(height: 24),
            _buildTipsSection(),
            const SizedBox(height: 24),
            _buildContactSection(),
            const SizedBox(height: 32),
            
            // Back to Proeven button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    kMainColor,
                    kMainColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: kMainColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Terug naar Proeven',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ga terug naar de hoofdpagina om proeven te bekijken',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Use pop to go back safely instead of pushAndRemoveUntil
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: kMainColor,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.list, size: 20),
                    label: const Text(
                      'Bekijk Proeven',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kMainColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.waving_hand, color: kMainColor, size: 28),
              const SizedBox(width: 12),
              const Text(
                'Welkom bij Jachtproef Alert!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kMainColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Deze app helpt voorjagers om jachtproeven te vinden, aan te melden en bij te houden. Hieronder vind je uitleg over alle functies.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSection(String title, IconData icon, List<String> features) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: kMainColor, size: 24),
            const SizedBox(width: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: kMainColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(left: 36, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: kMainColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature,
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ),
            ],
          ),
        )).toList(),
      ],
    );
  }

  Widget _buildDetailButtonsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Actieknoppen Uitleg',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildButtonExplanation(
            Icons.how_to_reg,
            'Inschrijven',
            'Geeft aan dat je interesse hebt in deze proef. Tik om je interesse aan/uit te zetten. Dit helpt je om bij te houden welke proeven je interessant vindt.',
            Colors.green,
          ),
          const SizedBox(height: 12),
          _buildButtonExplanation(
            Icons.notifications,
            'Meldingen',
            'Ontvang automatische herinneringen voor deze proef. Je krijgt meldingen wanneer de inschrijving opent en wanneer de proef begint.',
            Colors.orange,
          ),
          const SizedBox(height: 12),
          _buildButtonExplanation(
            Icons.calendar_today,
            'Toevoegen aan Agenda',
            'Voegt belangrijke data toe aan je telefoon agenda. Zowel de inschrijfdatum als de proefdatum worden toegevoegd zodat je niets vergeet.',
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildButtonExplanation(
            Icons.share,
            'Delen',
            'Deel de proef informatie met andere voorjagers via WhatsApp, email of andere apps. Handig om vrienden te informeren over interessante proeven.',
            kMainColor,
          ),
          const SizedBox(height: 12),
          _buildButtonExplanation(
            Icons.note_alt,
            'Persoonlijke Notities',
            'Voeg je eigen notities toe over de proef. Bijvoorbeeld: wat je moet meenemen, reistijd, of andere belangrijke informatie die je wilt onthouden.',
            Colors.purple,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tip: Gebruik deze knoppen om je proeven georganiseerd te houden en niets te missen!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonExplanation(IconData icon, String title, String description, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Handige Tips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Zet notificaties aan om geen proeven te missen\n'
            '• Gebruik filters om snel de juiste proef te vinden\n'
            '• Meld je vroeg aan - populaire proeven raken snel vol\n'
            '• Controleer regelmatig je agenda voor updates\n'
            '• Deel interessante proeven met andere voorjagers',
            style: TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.support_agent, color: Colors.grey[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Hulp Nodig?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Heb je vragen of problemen met de app? Neem contact op via de instellingen pagina of stuur een email naar support.',
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.touch_app, color: Colors.orange[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Hoe kom je bij de Proef Details?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'De proef details pagina is waar je alle belangrijke functies vindt! Zo kom je daar:',
            style: TextStyle(fontSize: 15, height: 1.4, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          _buildNavigationStep(
            '1',
            'Ga naar de Proeven pagina',
            'Gebruik de onderste navigatiebalk en tik op "Proeven"',
            Icons.list,
            kMainColor,
          ),
          const SizedBox(height: 12),
          _buildNavigationStep(
            '2',
            'Kies een proef',
            'Scroll door de lijst en zoek een interessante proef',
            Icons.search,
            Colors.blue,
          ),
          const SizedBox(height: 12),
          _buildNavigationStep(
            '3',
            'Tik op de proef',
            'Tik ergens op de proef kaart (niet alleen op de knoppen) om naar de details te gaan',
            Icons.tap_and_play,
            Colors.green,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Op de proef details pagina vind je alle actieknoppen: Inschrijven, Meldingen, Agenda, Delen en Notities!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationStep(String number, String title, String description, IconData icon, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
} 