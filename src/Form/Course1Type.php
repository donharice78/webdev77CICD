<?php

namespace App\Form;

use App\Entity\Campus;
use App\Entity\Course;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Bridge\Doctrine\Form\Type\EntityType;
use Symfony\Component\Validator\Constraints\NotBlank;
use Symfony\Component\OptionsResolver\OptionsResolver;
use Symfony\Component\Form\Extension\Core\Type\FileType;
use Symfony\Component\Validator\Constraints\GreaterThanOrEqual;

class Course1Type extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder
            // Ajouter le champ 'title' pour le titre du cours
            ->add('name', null, [
                'label' => 'Titre du Cours', // Label du champ
                'attr' => ['placeholder' => 'Entrez le titre du cours'], // Placeholder du champ
            ])
            ->add('campus', EntityType::class, [
                'class' => Campus::class,
                'choice_label' => 'name', // Display course name
                'multiple' => true,        // Allow selection of multiple courses
                'expanded' => true,        // Use checkboxes instead of a select box
            ])
            

            // Ajouter le champ 'description' pour la description du cours
            ->add('description', null, [
                'label' => 'Description', // Label du champ
                'attr' => ['placeholder' => 'Entrez la description du cours'], // Placeholder du champ
            ])
            
            // Ajouter le champ 'duration' pour la durée du cours
            ->add('duration', null, [
                'label' => 'Durée', // Label du champ
                'attr' => ['placeholder' => 'Entrez la durée du cours'], // Placeholder du champ
            ])
            
            // Ajouter le champ 'start_date' pour la date de début du cours
            ->add('start_date', null, [
                'widget' => 'single_text', // Afficher le champ comme un seul texte
                'label' => 'Date de Début', // Label du champ
                'attr' => ['placeholder' => 'Sélectionnez la date de début', // Placeholder du champ
                'min' => (new \DateTime())->format('Y-m-d'),
            ]
            ])

            ->add('end_date', null, [
                'widget' => 'single_text', // Afficher le champ comme un seul texte
                'label' => 'Date de Fin', // Label du champ
                'attr' => ['placeholder' => 'Sélectionnez la date de début', // Placeholder du champ
                'min' => (new \DateTime())->format('Y-m-d'),
            ]
            ])
            
            // Ajouter le champ 'course_format' pour le format du cours
            ->add('course_format', null, [
                'label' => 'Format du Cours', // Label du champ
                'attr' => ['placeholder' => 'Choisissez le format du cours'], // Placeholder du champ
            ])
            
            // Ajouter le champ 'prerequisities' pour les prérequis du cours
            ->add('prerequisities', null, [
                'label' => 'Prérequis', // Label du champ
                'attr' => ['placeholder' => 'Entrez les prérequis du cours'], // Placeholder du champ
            ])
            
            // Ajouter le champ 'course_fee' pour les frais du cours
            ->add('course_fee', null, [
                'label' => 'Frais du Cours', // Label du champ
                'attr' => ['placeholder' => 'Entrez les frais du cours'], // Placeholder du champ
            ])
            
            // Ajouter le champ 'image' pour télécharger une image du cours
            ->add('image', FileType::class, [
                'label' => 'Image', // Label du champ
                'multiple' => false, // Ne permet pas la sélection de plusieurs fichiers
                'mapped' => false,   // Ce champ n'est pas lié directement à une propriété de l'entité
                'required' => false, // Ce champ n'est pas obligatoire
               ])
        ;
    }

    public function configureOptions(OptionsResolver $resolver): void
    {
        // Configurer les options par défaut du formulaire
        $resolver->setDefaults([
            'data_class' => Course::class, // Associe ce formulaire à l'entité Course
        ]);
    }
}
