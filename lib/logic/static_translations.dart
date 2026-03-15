/// Static translations for all UI labels.
/// These never call the AI API — zero quota usage for UI text.
/// Only add strings that appear in the app UI.
library static_translations;

const Map<String, Map<String, String>> staticTranslations = {
  // ── Login Screen ──────────────────────────────────────────
  'Email': {'en': 'Email', 'fr': 'E-mail', 'es': 'Correo', 'de': 'E-Mail'},
  'Senha': {
    'en': 'Password',
    'fr': 'Mot de passe',
    'es': 'Contraseña',
    'de': 'Kennwort'
  },
  'Entrar': {
    'en': 'Login',
    'fr': 'Connexion',
    'es': 'Iniciar sesión',
    'de': 'Anmelden'
  },
  'Entrar com Google': {
    'en': 'Sign in with Google',
    'fr': 'Se connecter avec Google',
    'es': 'Entrar con Google',
    'de': 'Mit Google anmelden'
  },
  'Entrar com Facebook': {
    'en': 'Sign in with Facebook',
    'fr': 'Se connecter avec Facebook',
    'es': 'Entrar con Facebook',
    'de': 'Mit Facebook anmelden'
  },
  'Google': {'en': 'Google', 'fr': 'Google', 'es': 'Google', 'de': 'Google'},
  'Facebook': {
    'en': 'Facebook',
    'fr': 'Facebook',
    'es': 'Facebook',
    'de': 'Facebook'
  },
  'Esqueceu a senha?': {
    'en': 'Forgot password?',
    'fr': 'Mot de passe oublié ?',
    'es': '¿Olvidaste tu contraseña?',
    'de': 'Passwort vergessen?'
  },
  'Não tem uma conta? Registe-se': {
    'en': "Don't have an account? Sign up",
    'fr': "Pas de compte ? Inscrivez-vous",
    'es': "¿No tienes cuenta? Regístrate",
    'de': "Kein Konto? Registrieren"
  },
  'Criar conta': {
    'en': 'Create account',
    'fr': 'Créer un compte',
    'es': 'Crear cuenta',
    'de': 'Konto erstellen'
  },
  'Bem-vindo de volta': {
    'en': 'Welcome back',
    'fr': 'Bienvenue',
    'es': 'Bienvenido de nuevo',
    'de': 'Willkommen zurück'
  },
  'Aceder à plataforma': {
    'en': 'Access platform',
    'fr': 'Accéder à la plateforme',
    'es': 'Acceder a la plataforma',
    'de': 'Plattform aufrufen'
  },
  'EduGaming Platform': {
    'en': 'EduGaming Platform',
    'fr': 'EduGaming Platform',
    'es': 'EduGaming Platform',
    'de': 'EduGaming Platform'
  },
  'A vanguarda da educação': {
    'en': 'The forefront of education',
    'fr': "L'avant-garde de l'éducation",
    'es': 'La vanguardia de la educación',
    'de': 'Die Speerspitze der Bildung'
  },
  'ou entrar com': {
    'en': 'or sign in with',
    'fr': 'ou se connecter avec',
    'es': 'o iniciar sesión con',
    'de': 'oder anmelden mit'
  },
  'Plataforma de gamificação educativa': {
    'en': 'Educational gamification platform',
    'fr': "Plateforme de gamification éducative",
    'es': 'Plataforma de gamificación educativa',
    'de': 'Bildungs-Gamification-Plattform'
  },
  'Idioma': {'en': 'Language', 'fr': 'Langue', 'es': 'Idioma', 'de': 'Sprache'},
  'Selecionar idioma': {
    'en': 'Select language',
    'fr': 'Sélectionner la langue',
    'es': 'Seleccionar idioma',
    'de': 'Sprache auswählen'
  },

  // ── Navigation / Common ───────────────────────────────────
  'Início': {'en': 'Home', 'fr': 'Accueil', 'es': 'Inicio', 'de': 'Start'},
  'Sair': {
    'en': 'Sign out',
    'fr': 'Déconnexion',
    'es': 'Cerrar sesión',
    'de': 'Abmelden'
  },
  'Perfil': {'en': 'Profile', 'fr': 'Profil', 'es': 'Perfil', 'de': 'Profil'},
  'Configurações': {
    'en': 'Settings',
    'fr': 'Paramètres',
    'es': 'Configuración',
    'de': 'Einstellungen'
  },
  'Guardar': {
    'en': 'Save',
    'fr': 'Enregistrer',
    'es': 'Guardar',
    'de': 'Speichern'
  },
  'Cancelar': {
    'en': 'Cancel',
    'fr': 'Annuler',
    'es': 'Cancelar',
    'de': 'Abbrechen'
  },
  'Confirmar': {
    'en': 'Confirm',
    'fr': 'Confirmer',
    'es': 'Confirmar',
    'de': 'Bestätigen'
  },
  'Fechar': {'en': 'Close', 'fr': 'Fermer', 'es': 'Cerrar', 'de': 'Schließen'},
  'Carregando...': {
    'en': 'Loading...',
    'fr': 'Chargement...',
    'es': 'Cargando...',
    'de': 'Laden...'
  },
  'Erro': {'en': 'Error', 'fr': 'Erreur', 'es': 'Error', 'de': 'Fehler'},
  'Sucesso': {'en': 'Success', 'fr': 'Succès', 'es': 'Éxito', 'de': 'Erfolg'},
  'Sim': {'en': 'Yes', 'fr': 'Oui', 'es': 'Sí', 'de': 'Ja'},
  'Não': {'en': 'No', 'fr': 'Non', 'es': 'No', 'de': 'Nein'},

  // ── Teacher Dashboard ─────────────────────────────────────
  'Painel do Professor': {
    'en': "Teacher Dashboard",
    'fr': 'Tableau de bord enseignant',
    'es': 'Panel del profesor',
    'de': 'Lehrerpanel'
  },
  'As Minhas Disciplinas': {
    'en': 'My subjects',
    'fr': 'Mes matières',
    'es': 'Mis asignaturas',
    'de': 'Meine Fächer'
  },
  'Nova Disciplina': {
    'en': 'New subject',
    'fr': 'Nouvelle matière',
    'es': 'Nueva asignatura',
    'de': 'Neues Fach'
  },
  'Duplicar Disciplina': {
    'en': 'Duplicate subject',
    'fr': 'Dupliquer la matière',
    'es': 'Duplicar asignatura',
    'de': 'Fach duplizieren'
  },
  'Selecione o novo ano letivo para a cópia:': {
    'en': 'Select the new academic year for the copy:',
    'fr': "Sélectionnez la nouvelle année scolaire pour la copie :",
    'es': 'Seleccione el nuevo año académico para la copia:',
    'de': 'Wählen Sie das neue Schuljahr für die Kopie:'
  },
  'Filtrar por Ano Letivo': {
    'en': 'Filter by Academic Year',
    'fr': "Filtrer par année scolaire",
    'es': 'Filtrar por año académico',
    'de': 'Nach Schuljahr filtern'
  },
  'GERIR': {
    'en': 'MANAGE',
    'fr': 'GÉRER',
    'es': 'GESTIONAR',
    'de': 'VERWALTEN'
  },
  'Resultados da Pesquisa': {
    'en': 'Search Results',
    'fr': 'Résultats de recherche',
    'es': 'Resultados de la búsqueda',
    'de': 'Suchergebnisse'
  },
  'Componentes': {
    'en': 'Components',
    'fr': 'Composants',
    'es': 'Componentes',
    'de': 'Komponenten'
  },
  'Conteúdos': {
    'en': 'Contents',
    'fr': 'Contenus',
    'es': 'Contenidos',
    'de': 'Inhalte'
  },
  'Avaliação/Ranking': {
    'en': 'Assessment/Ranking',
    'fr': 'Évaluation/Classement',
    'es': 'Evaluación/Ránking',
    'de': 'Bewertung/Rangliste'
  },
  'Regras de Avaliação': {
    'en': 'Assessment Rules',
    'fr': "Règles d'évaluation",
    'es': 'Reglas de evaluación',
    'de': 'Bewertungsregeln'
  },
  'Novo': {'en': 'New', 'fr': 'Nouveau', 'es': 'Nuevo', 'de': 'Neu'},
  'Nenhuma componente definida.': {
    'en': 'No component defined.',
    'fr': 'Aucun composant défini.',
    'es': 'Ningún componente definido.',
    'de': 'Keine Komponente definiert.'
  },
  'Vincular Itens': {
    'en': 'Link Items',
    'fr': 'Lier des éléments',
    'es': 'Vincular elementos',
    'de': 'Elemente verknüpfen'
  },
  'Remover': {
    'en': 'Remove',
    'fr': 'Supprimer',
    'es': 'Eliminar',
    'de': 'Entfernen'
  },
  'DocTalk: Conversar com IA sobre todos os conteúdos': {
    'en': 'DocTalk: Chat with AI about all contents',
    'fr': 'DocTalk : Discuter avec l\'IA sur tous les contenus',
    'es': 'DocTalk: Chatear con IA sobre todos los contenidos',
    'de': 'DocTalk: Mit KI über alle Inhalte chatten'
  },
  'Ainda não carregou ficheiros.': {
    'en': 'No files uploaded yet.',
    'fr': 'Aucun fichier téléchargé.',
    'es': 'Aún no se han subido archivos.',
    'de': 'Noch keine Dateien hochgeladen.'
  },
  'Adicionar Jogo (URL)': {
    'en': 'Add Game (URL)',
    'fr': 'Ajouter un jeu (URL)',
    'es': 'Añadir juego (URL)',
    'de': 'Spiel hinzufügen (URL)'
  },
  'Itens de Avaliação e Ranking': {
    'en': 'Assessment & Ranking Items',
    'fr': 'Éléments d\'évaluation et de classement',
    'es': 'Elementos de evaluación y ránking',
    'de': 'Bewertungs- und Ranglistenelemente'
  },
  'Nenhum exame ou jogo configurado.': {
    'en': 'No exam or game configured.',
    'fr': 'Aucun examen ou jeu configuré.',
    'es': 'Ningún examen o juego configurado.',
    'de': 'Keine Prüfung oder Spiel konfiguriert.'
  },
  'TOTAL PONDERAÇÃO': {
    'en': 'TOTAL WEIGHT',
    'fr': 'PONDÉRATION TOTALE',
    'es': 'PONDERACIÓN TOTAL',
    'de': 'GESAMTGEWICHTUNG'
  },
  'Solicitações Pendentes': {
    'en': 'Pending Requests',
    'fr': 'Demandes en attente',
    'es': 'Solicitudes pendientes',
    'de': 'Ausstehende Anfragen'
  },
  'Alunos com Acesso': {
    'en': 'Students with Access',
    'fr': 'Élèves avec accès',
    'es': 'Alumnos con acceso',
    'de': 'Schüler mit Zugang'
  },
  'Alunos': {
    'en': 'Students',
    'fr': 'Élèves',
    'es': 'Alumnos',
    'de': 'Schüler'
  },
  'Documentos': {
    'en': 'Documents',
    'fr': 'Documents',
    'es': 'Documentos',
    'de': 'Dokumente'
  },
  'Adicionar conteúdo': {
    'en': 'Add content',
    'fr': 'Ajouter du contenu',
    'es': 'Añadir contenido',
    'de': 'Inhalt hinzufügen'
  },
  'DocTalk AI': {
    'en': 'DocTalk AI',
    'fr': 'DocTalk IA',
    'es': 'DocTalk IA',
    'de': 'DocTalk KI'
  },
  'Ranking': {
    'en': 'Ranking',
    'fr': 'Classement',
    'es': 'Clasificación',
    'de': 'Rangliste'
  },
  'Jogos': {'en': 'Games', 'fr': 'Jeux', 'es': 'Juegos', 'de': 'Spiele'},
  'Avaliação': {
    'en': 'Assessment',
    'fr': 'Évaluation',
    'es': 'Evaluación',
    'de': 'Bewertung'
  },

  // ── Student Dashboard ─────────────────────────────────────
  'Painel do Aluno': {
    'en': "Student Dashboard",
    'fr': "Tableau de bord élève",
    'es': 'Panel del alumno',
    'de': 'Schülerpanel'
  },
  'As Tuas Disciplinas': {
    'en': 'Your subjects',
    'fr': 'Vos matières',
    'es': 'Tus asignaturas',
    'de': 'Deine Fächer'
  },
  'Procurar Novas Disciplinas': {
    'en': 'Search for New Subjects',
    'fr': 'Rechercher de nouvelles matières',
    'es': 'Buscar nuevas asignaturas',
    'de': 'Nach neuen Fächern suchen'
  },
  'Inscrições e Acesso': {
    'en': 'Enrollments and Access',
    'fr': 'Inscriptions et accès',
    'es': 'Inscripciones y acceso',
    'de': 'Einschreibungen und Zugang'
  },
  'Disciplinas disponíveis': {
    'en': 'Available subjects',
    'fr': 'Matières disponibles',
    'es': 'Asignaturas disponibles',
    'de': 'Verfügbare Fächer'
  },
  'Inscrever-se': {
    'en': 'Enrol',
    'fr': "S'inscrire",
    'es': 'Inscribirse',
    'de': 'Einschreiben'
  },

  // ── Admin Dashboard ───────────────────────────────────────
  'Painel Administrativo': {
    'en': 'Admin Dashboard',
    'fr': "Tableau d'administration",
    'es': 'Panel administrativo',
    'de': 'Administrationsbereich'
  },
  'Instituições': {
    'en': 'Institutions',
    'fr': 'Établissements',
    'es': 'Instituciones',
    'de': 'Institutionen'
  },
  'Utilizadores': {
    'en': 'Users',
    'fr': 'Utilisateurs',
    'es': 'Usuarios',
    'de': 'Benutzer'
  },

  // ── DocTalk Chat ─────────────────────────────────────────
  'Escreva uma mensagem...': {
    'en': 'Type a message...',
    'fr': 'Saisissez un message...',
    'es': 'Escribe un mensaje...',
    'de': 'Nachricht eingeben...'
  },
  'Enviar': {'en': 'Send', 'fr': 'Envoyer', 'es': 'Enviar', 'de': 'Senden'},
  'Inicializando sessão AI...': {
    'en': 'Initializing AI session...',
    'fr': 'Initialisation de la session IA...',
    'es': 'Inicializando sesión IA...',
    'de': 'KI-Sitzung wird initialisiert...'
  },
};

/// Look up a static translation. Returns null if not found (should then use AI).
String? getStaticTranslation(String text, String langCode) {
  if (langCode == 'pt') return text;
  return staticTranslations[text]?[langCode];
}
