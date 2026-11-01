import logging
from django.conf import settings

logger = logging.getLogger('shieldnet.security')


class PrimaryReplicaDatabaseRouter:
    """
    Routeur de base de données Haute Disponibilité (HA) & Clustering.
    Sépare les lectures et les écritures pour répartir la charge (Read/Write Splitting) :
    - Écritures (INSERT, UPDATE, DELETE) -> Nœud Principal ('default' / Primary)
    - Lectures (SELECT, lookups anti-spam) -> Nœud Réplique ('replica' / Read-Only Standby)
    - Migrations & Schéma -> Nœud Principal exclusivement ('default')
    
    En l'absence de réplique configurée ou en environnement de test, toutes les
    requêtes sont aiguillées en toute transparence vers le nœud 'default'.
    """

    def db_for_read(self, model, **hints):
        """Achemine les opérations de lecture vers la réplique si disponible."""
        # Si une instance spécifique est spécifiée dans les hints
        instance = hints.get('instance')
        if instance is not None and getattr(instance, '_state', None) is not None:
            db = instance._state.db
            if db:
                return db

        # Si le cluster dispose d'un nœud réplique configuré
        if 'replica' in getattr(settings, 'DATABASES', {}):
            return 'replica'

        return 'default'

    def db_for_write(self, model, **hints):
        """Achemine impérativement les opérations d'écriture vers le nœud primaire."""
        return 'default'

    def allow_relation(self, obj1, obj2, **hints):
        """Autorise les relations si les deux objets font partie du pool du cluster."""
        db_set = {'default', 'replica'}
        if obj1._state.db in db_set and obj2._state.db in db_set:
            return True
        return None

    def allow_migrate(self, db, app_label, model_name=None, **hints):
        """Garantit que les migrations DDL s'exécutent EXCLUSIVEMENT sur le nœud primaire."""
        return db == 'default'
