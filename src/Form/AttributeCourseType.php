<?php

namespace App\Form;

use App\Entity\User;
use App\Entity\Course;
use App\Repository\UserRepository;
use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Bridge\Doctrine\Form\Type\EntityType;
use Symfony\Component\OptionsResolver\OptionsResolver;

class AttributeCourseType extends AbstractType
{
    public function buildForm(FormBuilderInterface $builder, array $options): void
    {
        $builder

        ->add('user', EntityType::class, [
            'class' => User::class,
            'choice_label' => 'username', // Display user's username
            'placeholder' => 'Select a user', // Placeholder text for the select box
            'query_builder' => function (UserRepository $userRepository) {
                return $userRepository->createQueryBuilder('u')
                    ->where('u.roles NOT LIKE :role')
                    ->setParameter('role', '%"ROLE_ADMIN"%'); // Exclude users with ROLE_ADMIN
            },
        ])
        ->add('courses', EntityType::class, [
            'class' => Course::class,
            'choice_label' => 'name', // Display course name
            'multiple' => true,        // Allow selection of multiple courses
            'expanded' => true,        // Use checkboxes instead of a select box
        ]);
}

public function configureOptions(OptionsResolver $resolver): void
{
    $resolver->setDefaults([
        'csrf_protection' => true,   // Enable CSRF protection
    ]);
}
}
