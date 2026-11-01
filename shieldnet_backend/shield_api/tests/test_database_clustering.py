from django.test import TestCase, override_settings
from shield_api.models import BlacklistedNumber
from shield_api.routers import PrimaryReplicaDatabaseRouter


class PrimaryReplicaRouterTestCase(TestCase):
    """
    Tests de validation du routeur de clustering et haute disponibilité (HA).
    Vérifie la séparation stricte lecture/écriture (Read/Write splitting)
    et le confinement des migrations sur le nœud primaire.
    """

    def setUp(self):
        self.router = PrimaryReplicaDatabaseRouter()

    def test_writes_always_go_to_primary(self):
        """Les écritures doivent impérativement être routées vers le nœud 'default'."""
        db = self.router.db_for_write(BlacklistedNumber)
        self.assertEqual(db, 'default')

    def test_reads_fallback_to_primary_when_no_replica(self):
        """En l'absence de réplique, les lectures se font sur le nœud primaire."""
        with override_settings(DATABASES={'default': {}}):
            db = self.router.db_for_read(BlacklistedNumber)
            self.assertEqual(db, 'default')

    def test_reads_routed_to_replica_when_configured(self):
        """Lorsque le cluster dispose d'une réplique, les lectures y sont orientées."""
        with override_settings(DATABASES={'default': {}, 'replica': {}}):
            db = self.router.db_for_read(BlacklistedNumber)
            self.assertEqual(db, 'replica')

    def test_migrations_strictly_forbidden_on_replica(self):
        """Les migrations DDL ne doivent JAMAIS s'exécuter sur une réplique en lecture seule."""
        self.assertTrue(self.router.allow_migrate('default', 'shield_api'))
        self.assertFalse(self.router.allow_migrate('replica', 'shield_api'))
        self.assertFalse(self.router.allow_migrate('analytics', 'shield_api'))

    def test_allow_relations_within_cluster(self):
        """Les relations entre objets du même pool de cluster doivent être autorisées."""
        obj1 = BlacklistedNumber(phone_hash="a" * 64)
        obj2 = BlacklistedNumber(phone_hash="b" * 64)
        obj1._state.db = 'default'
        obj2._state.db = 'replica'
        self.assertTrue(self.router.allow_relation(obj1, obj2))
