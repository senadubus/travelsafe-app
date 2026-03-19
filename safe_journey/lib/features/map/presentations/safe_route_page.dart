import 'package:flutter/material.dart';

class SafeRoutePage extends StatelessWidget {
  const SafeRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            _SearchFields(),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.grey[300],
                ),
                child: const Center(child: Text("ROTA HARİTASI")),
              ),
            ),
            _RouteOptions(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "En Güvenli Rota",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _SearchFields extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InputField("Başlangıç"),
        _InputField("Varış noktası"),
      ],
    );
  }
}

class _InputField extends StatelessWidget {
  final String hint;
  const _InputField(this.hint);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _RouteOptions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          _RouteCard("En Güvenli", "Düşük risk", Colors.green),
          _RouteCard("Dengeli", "Orta risk", Colors.orange),
          _RouteCard("En Hızlı", "Yüksek risk", Colors.red),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final String title;
  final String risk;
  final Color color;

  const _RouteCard(this.title, this.risk, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Text(
            risk,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
