# Intégration Visual TOM Jira Service Management
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE.md)&nbsp;
[![fr](https://img.shields.io/badge/lang-en-red.svg)](README.md)  

Ce projet fournit des scripts pour créer et gérer des tickets Jira Service Management à partir de Visual TOM. Pour éviter trop de tickets isolés, le script vérifie si un ticket existe déjà pour le nom de l'objet et n'est pas fermé.  
Si c'est le cas, il créera un ticket enfant avec les nouvelles informations.  
Sinon, il créera un nouveau ticket.  
Si fourni, le script ajoutera les logs de sortie et d'erreur en tant que pièces jointes au ticket.

# Disclaimer
Aucun support ni garanties ne seront fournis par Absyss SAS pour ce projet et fichiers associés. L'utilisation est à vos propres risques.

Absyss SAS ne peut être tenu responsable des dommages causés par l'utilisation d'un des fichiers mis à disposition dans ce dépôt Github.

Il est possible de faire appel à des jours de consulting pour l'implémentation.

# Prérequis

* Visual TOM 7.2.1f ou supérieur (les versions inférieures peuvent fonctionner mais sans pièce jointe de log)
* Instance Jira Service Management avec API REST activée
* Champ personnalisé dans Jira pour stocker le nom de l'objet Visual TOM (Jobs, Applications, Agents, etc.)
* Python 3.10 ou supérieur ou PowerShell 7.0 ou supérieur

# Démarrage rapide

## Configuration automatique (Recommandé)

Nous fournissons des scripts de configuration interactifs qui découvrent automatiquement votre configuration Jira et génèrent le fichier de configuration pour vous :

### PowerShell (Windows)
```powershell
.\setup_config.ps1
```

### Python (Multi-plateforme)
```bash
python setup_config.py
```

Ces scripts vont :
- ✅ Se connecter à votre instance Jira
- ✅ Lister les projets, types d'issues et priorités disponibles
- ✅ Détecter automatiquement les champs personnalisés
- ✅ Trouver les Request Types pour Jira Service Management
- ✅ Générer le fichier de configuration avec les IDs corrects

**C'est la façon la plus simple de commencer !**

## Configuration manuelle

Si vous préférez configurer manuellement, vous pouvez copier les fichiers templates :

```bash
# Pour Python
cp config.template.py config.py

# Pour PowerShell
cp config.template.ps1 config.ps1
```

Puis éditez le fichier de configuration avec vos identifiants Jira et les IDs des champs.

# Utilisation

Vous pouvez choisir entre le script PowerShell ou le script Python selon votre environnement.  
Vous devez remplacer FULL_PATH_TO_SCRIPT, PROJECT_KEY, ISSUE_TYPE, PRIORITY et ASSIGNEE par vos valeurs.

### Script PowerShell

1. Exécutez le script de configuration ou éditez le fichier config.ps1 avec vos identifiants Jira
2. Créez une alarme dans Visual TOM pour déclencher le script (exemple ci-dessous pour un job à adapter)

```powershell
powershell.exe -file FULL_PATH_TO_SCRIPT\Jira_CreateTicket.ps1 -ProjectKey "PROJ" -Summary "Job {VT_JOB_FULLNAME} a échoué" -Description "Le job {VT_JOB_FULLNAME} a échoué avec erreur" -ObjectName "{VT_JOB_FULLNAME}" -Priority "High" -OutAttachmentName "{VT_JOB_LOG_OUT_NAME}" -OutAttachmentFile "{VT_JOB_LOG_OUT_FILE}" -ErrorAttachmentName "{VT_JOB_LOG_ERR_NAME}" -ErrorAttachmentFile "{VT_JOB_LOG_ERR_FILE}"
```

### Script Python

1. Exécutez le script de configuration ou éditez le fichier config.py avec vos identifiants Jira
2. Créez une alarme dans Visual TOM pour déclencher le script (exemple ci-dessous pour un job à adapter)

```bash
python3 FULL_PATH_TO_SCRIPT/Jira_CreateTicket.py --projectKey PROJ --summary "Job {VT_JOB_FULLNAME} a échoué" --description "Le job {VT_JOB_FULLNAME} a échoué avec erreur" --objectName "{VT_JOB_FULLNAME}" --priority "High" --outAttachmentName "{VT_JOB_LOG_OUT_NAME}" --outAttachmentFile "{VT_JOB_LOG_OUT_FILE}" --errorAttachmentName "{VT_JOB_LOG_ERR_NAME}" --errorAttachmentFile "{VT_JOB_LOG_ERR_FILE}"
```

## Configuration

### Authentification

Vous devez créer un token API dans Jira :
1. Allez dans les paramètres de votre profil Jira ou directementici : https://id.atlassian.com/manage-profile/security/api-tokens
2. Naviguez vers Sécurité → Tokens API
3. Créez un nouveau token API
4. Encodez votre email et token API en base64 : `echo -n "votre-email@domain.com:votre-api-token" | base64`

### Champs personnalisés

Pour mapper les variables VTOM aux champs personnalisés Jira :
1. Allez dans les paramètres de votre projet Jira
2. Naviguez vers Champs → Champs personnalisés
3. Notez les IDs des champs (ils commencent par `customfield_`)
4. Mettez à jour les `custom_field_mappings` dans votre fichier de configuration

# Actions disponibles

## Objectifs global: 

- ➡️ Créer automatiquement des tickets Jira à partir d’alarmes VTOM
- ➡️ Éviter les doublons en réutilisant un ticket existant si possible
- ➡️ Tracer les alarmes successives (via tickets liés + commentaires + pièces jointes)
  
1. Il se connecte à Jira via l’API REST
2. Il analyse l’alarme VTOM reçue (paramètres CLI)
3. Il cherche s’il existe déjà un ticket ouvert pour le même objet VTOM
4. Selon le cas :
   soit il crée un nouveau ticket
   soit il crée un ticket lié à un ticket existant
5. Il ajoute :
   des pièces jointes (logs)
   un commentaire horodaté

## Arguments du script 
Le script est lancé en ligne de commande avec les paramètres suivants : 
- --projectKey → projet Jira
- --summary → résumé du ticket
- --description → description détaillée
- --objectName → nom de l’objet VTOM
- --severity → gravité VTOM
- --alarmType → type d’alarme VTOM
- fichiers de logs à joindre (stdout / stderr)

### Mapping des priorités et types d'issues

Les scripts supportent le mapping automatique des niveaux de sévérité VTOM vers les priorités Jira et des types d'alarmes vers les types d'issues. Configurez ces mappings dans votre fichier de configuration.



# Licence
Ce projet est sous licence Apache 2.0. Voir le fichier [LICENCE](license) pour plus de détails.


# Code de conduite
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-v2.1%20adopted-ff69b4.svg)](code-of-conduct.md)  
Absyss SAS a adopté le [Contributor Covenant](CODE_OF_CONDUCT.md) en tant que Code de Conduite et s'attend à ce que les participants au projet y adhère également. Merci de lire [document complet](CODE_OF_CONDUCT.md) pour comprendre les actions qui seront ou ne seront pas tolérées.
