import 'dart:io';

void main() {
  final mktPath = 'c:/Users/josen/apptest/lib/screens/institution/marketing/marketing_details_screen.dart';
  final destPath = 'c:/Users/josen/apptest/lib/screens/institution/infrastructure/infrastructure_details_screen.dart';
  
  var content = File(mktPath).readAsStringSync();
  
  // Replacements for imports and models
  content = content.replaceAll("import '../../../../models/marketing_event_model.dart';", "import '../../../../models/infrastructure_model.dart';");
  content = content.replaceAll("MarketingEvent", "Infrastructure");
  content = content.replaceAll("MarketingDetailsScreen", "InfrastructureDetailsScreen");
  content = content.replaceAll("Marketing_events", "Infrastructures"); // if any
  content = content.replaceAll("marketing", "infrastructure"); // variables
  content = content.replaceAll("_currentevent", "_currentinfra");
  content = content.replaceAll("widget.event", "widget.infrastructure");
  content = content.replaceAll("event", "infrastructure"); // Be careful with this, but should be mostly correct for the state
  content = content.replaceAll("Marketing", "Infrastructure");
  content = content.replaceAll("marketingMedia", "infrastructureMedia"); // Firebase functions
  
  // Fix the specific UI fields that were for Marketing
  // We need to replace the marketing fields (objectives, targetAudience, budget, roi) with:
  // address, contact, description, marketValue
  
  // Write to file
  File(destPath).writeAsStringSync(content);
}
