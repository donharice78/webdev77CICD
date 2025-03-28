<?php

namespace App\Controller;

use App\Entity\User;
use App\Entity\Campus;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;


#[Route('/view')]

class ShowController extends AbstractController
{
 
    #[Route('/{username}', name: 'app_admin_user_show')]
    public function show(User $user, Campus $campus)
    {
      


        return $this->render('admin_user/student_dashboard.html.twig', [
            'user' => $user,
            
            
        ]);
    }

}