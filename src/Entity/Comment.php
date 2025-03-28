<?php

namespace App\Entity;

use Doctrine\ORM\Mapping as ORM;
use Doctrine\DBAL\Types\Types;
use App\Repository\CommentRepository;

#[ORM\Entity(repositoryClass: CommentRepository::class)]
class Comment
{
    #[ORM\Id]
    #[ORM\GeneratedValue]
    #[ORM\Column]
    private ?int $id = null; // Identifiant unique du commentaire

    #[ORM\Column(type: Types::TEXT)]
    private ?string $content = null; // Contenu du commentaire

  

    /**
     * Note attribuée dans le commentaire
     *
     * @ORM\Column(type="integer")
     */
    private ?int $rating = null;

    #[ORM\ManyToOne(inversedBy: 'comments')]
    private ?User $user = null; // Note associée au commentaire

    // Méthode pour obtenir l'identifiant du commentaire
    public function getId(): ?int
    {
        return $this->id;
    }

    // Méthode pour obtenir le contenu du commentaire
    public function getContent(): ?string
    {
        return $this->content;
    }

    // Méthode pour définir le contenu du commentaire
    public function setContent(string $content): static
    {
        $this->content = $content;
        return $this; // Retourne l'instance actuelle pour la chaîne de méthodes
    }

 

    // Méthode pour obtenir la note du commentaire
    public function getRating(): ?int
    {
        return $this->rating;
    }

    // Méthode pour définir la note du commentaire
    public function setRating(int $rating): static
    {
        $this->rating = $rating;
        return $this; // Retourne l'instance actuelle pour la chaîne de méthodes
    }

    public function getUser(): ?User
    {
        return $this->user;
    }

    public function setUser(?User $user): static
    {
        $this->user = $user;

        return $this;
    }
}
