<?php

declare(strict_types=1);

namespace DoctrineMigrations;

use Doctrine\DBAL\Schema\Schema;
use Doctrine\Migrations\AbstractMigration;

/**
 * Auto-generated Migration: Please modify to your needs!
 */
final class Version20241028081913 extends AbstractMigration
{
    public function getDescription(): string
    {
        return '';
    }

    public function up(Schema $schema): void
    {
        // this up() migration is auto-generated, please modify it to your needs
        $this->addSql('CREATE TABLE course_campus (course_id INT NOT NULL, campus_id INT NOT NULL, INDEX IDX_3331A95C591CC992 (course_id), INDEX IDX_3331A95CAF5D55E1 (campus_id), PRIMARY KEY(course_id, campus_id)) DEFAULT CHARACTER SET utf8mb4 COLLATE `utf8mb4_unicode_ci` ENGINE = InnoDB');
        $this->addSql('ALTER TABLE course_campus ADD CONSTRAINT FK_3331A95C591CC992 FOREIGN KEY (course_id) REFERENCES course (id) ON DELETE CASCADE');
        $this->addSql('ALTER TABLE course_campus ADD CONSTRAINT FK_3331A95CAF5D55E1 FOREIGN KEY (campus_id) REFERENCES campus (id) ON DELETE CASCADE');
    }

    public function down(Schema $schema): void
    {
        // this down() migration is auto-generated, please modify it to your needs
        $this->addSql('ALTER TABLE course_campus DROP FOREIGN KEY FK_3331A95C591CC992');
        $this->addSql('ALTER TABLE course_campus DROP FOREIGN KEY FK_3331A95CAF5D55E1');
        $this->addSql('DROP TABLE course_campus');
    }
}
