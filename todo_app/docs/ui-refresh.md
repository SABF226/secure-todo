# Refonte visuelle — thème violet

**Périmètre** : présentation uniquement. Aucun bloc, cas d'usage, repository, enregistrement DI,
ni garde de route n'a été modifié. Les 25 tests unitaires et de widget passent **sans être touchés**,
ce qui est la meilleure preuve que le comportement est identique.

---

## 1. Fichiers

| Fichier | Nature | Rôle |
|---|---|---|
| `lib/core/theme/app_theme.dart` | nouveau | palette, typographie et styles de composants (clair + sombre) |
| `lib/core/widgets/app_logo.dart` | nouveau | la marque (carré violet arrondi + glyphe) |
| `lib/core/widgets/splash_screen.dart` | nouveau | écran d'attente pendant `AuthStarted` |
| `lib/features/auth/presentation/widgets/auth_header.dart` | nouveau | en-tête dégradé partagé par connexion / inscription |
| `lib/app.dart` | modifié | `theme` + `darkTheme` + `ThemeMode.system`, titre « Secure Todo » |
| `lib/core/router/app_router.dart` | modifié | le `builder` de `/splash` utilise `SplashScreen` (une ligne) |
| `login_page.dart`, `register_page.dart` | modifiés | mise en page + bouton afficher/masquer le mot de passe |
| `todos_page.dart` | modifié | app bar, barre de filtres pleine largeur, états vide/erreur, FAB étendu |
| `todo_tile.dart` | modifié | carte arrondie, case circulaire, fond de glissement arrondi |
| `add_todo_sheet.dart` | modifié | poignée de glissement, titre « New todo » |

Les callbacks, validateurs, événements de bloc et textes assertés par les tests sont inchangés
(`'My todos (n left)'`, `Retry`, `tooltip: 'Sign out'`, `'Sign in'`…).

---

## 2. La palette

Une seule couleur source :

```dart
static const Color seed = Color(0xFF7C3AED); // violet
```

`ColorScheme.fromSeed` en dérive tous les rôles Material 3 (`primary`, `primaryContainer`,
`surfaceContainerLow`, `outlineVariant`, `inverseSurface`…). Conséquences :

- les pages n'écrivent **aucune** couleur en dur : elles demandent `Theme.of(context).colorScheme`,
  donc le mode sombre ne demande aucune branche `if (isDark)` ;
- changer la marque plus tard = changer une ligne ;
- le contraste texte/fond est garanti par Material, pas à l'œil.

L'application démarre en **thème clair** (`themeMode: ThemeMode.light`). Le schéma sombre est
construit et prêt, mais n'est pas imposé par le réglage du téléphone : il suffit de passer à
`ThemeMode.system` dans `app.dart` pour le réactiver.

L'en-tête d'authentification n'est plus un bloc violet saturé : c'est un lavis
`primaryContainer` qui se fond dans le fond de page.

```dart
colors: [
  scheme.primaryContainer.withValues(alpha: 0.75),
  scheme.surface,
]
```

La marque reste lisible (pastille `primary` + mot-clé violet) sans assombrir le haut de l'écran.

---

## 3. Styles mis dans le thème (et non dans les pages)

| Composant | Réglage |
|---|---|
| Cartes | élévation 0, bordure `outlineVariant` à 70 %, rayon 18 |
| Champs | remplis, sans bordure, bordure violette 1,6 px au focus |
| Boutons remplis | hauteur min. 52, rayon 16, libellé gras |
| `SegmentedButton` | segment sélectionné rempli en violet, rayon 14 |
| `Checkbox` | circulaire, rempli en violet une fois coché |
| FAB | violet, rayon 18, libellé gras |
| `SnackBar` | flottante, rayon 14, `inverseSurface` |
| `BottomSheet` | rayon 28 en haut, poignée visible, sans teinte de surface |

Ainsi `TodoTile` et `TodosPage` restent courts : la cohérence vient du thème, pas de la répétition.

---

## 4. Améliorations d'usage (au-delà de la couleur)

1. **Afficher / masquer le mot de passe** — état purement local (`bool _obscure`), aucun impact sur
   l'envoi du formulaire.
2. **Barre de filtres pleine largeur** avec icônes : trois zones tactiles égales, plus faciles à
   viser au pouce que trois pastilles collées au centre.
3. **États vides contextualisés** : « Nothing here yet », « All done », « Nothing completed ».
   Avant, filtrer sur *Done* avec zéro tâche terminée affichait « Nothing here. Tap +… », ce qui
   était faux (il y avait des tâches, simplement aucune terminée).
4. **Pull-to-refresh toujours possible** : `AlwaysScrollableScrollPhysics` sur les deux listes.
   Sans cela, avec une seule tâche, la liste ne défile pas et le geste de rafraîchissement ne
   déclenche rien.
5. **FAB étendu « New todo »** : l'action principale est nommée, plus seulement une icône `+`.
6. **Erreur de chargement** : icône, message, bouton *Retry* (la `SnackBar` reste pour les erreurs
   d'action, pas pour l'écran vide).
7. **Liste avec espacement** (`ListView.separated`, 10 px) et marge basse de 96 px pour que la
   dernière tâche ne passe jamais sous le FAB.
8. **Indicateur de chargement lisible** : dans un bouton rempli violet, le spinner utilisait
   `primary` — donc violet sur violet. Il prend maintenant `onPrimary`.

---

## 5. Vérifications

```
$ flutter analyze
No issues found!

$ flutter test
00:08 +25 ~16: All tests passed!     (16 tests d'intégration ignorés)

$ flutter build web
✓ Built build/web
```

Aucun test n'a été adapté : les tests de page cliquent la `Checkbox`, glissent la tuile et lisent
le titre — tout cela fonctionne avec la nouvelle carte.

---

## 6. Piste suivante

Le mode sombre suit le système. Pour laisser l'utilisateur choisir (et s'en souvenir), il suffit
d'ajouter un `ThemeCubit` + `hydrated_bloc` et de remplacer `themeMode: ThemeMode.system` par
`themeMode: context.select((ThemeCubit c) => c.state)`. `app_theme.dart` n'aurait pas à changer.
